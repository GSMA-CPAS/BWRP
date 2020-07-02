#!/bin/bash
. setup.sh

CA_URL="ca-$MYHOST.$KUBENS:$CA_PORT"
CA_ROOT_DIT="/mnt/data/CA"
CA_CLIENT_DIR="/mnt/data/ca-client"
CA_CLIENT_OPTS="--caname ca.$HOSTNAME.$DOMAIN -H $CA_CLIENT_DIR --tls.certfiles $CA_ROOT_DIT/tls-cert.pem"
PEER_DIR="/mnt/data/peer"
PEER_BASE="$PEER_DIR/peers/peer0.$HOSTNAME.$DOMAIN/"

echo "> setting namespace"
kubectl config set-context --current --namespace=$KUBENS

echo "> removing peer certificates [FIXME: REMOVE THIS, JUST FOR DEBUG]"
kubectl exec fabric-ca-tools -- rm -rf $PEER_BASE

echo "> deploying helper script"
kubectl cp process_pem.sh fabric-tools:/root

echo "> enrolling admin user"
kubectl exec fabric-ca-tools -- fabric-ca-client enroll -u https://admin:$CA_ADMINPW@$CA_URL $CA_CLIENT_OPTS
echo "> register peer0 user"
kubectl exec fabric-ca-tools -- fabric-ca-client register --id.name peer0 --id.secret $CA_PEERPW --id.type peer $CA_CLIENT_OPTS | sed 's|Password: \(.*\)|Password: *** hidden ***\r|'
echo "> enrolling peer0 user"
#kubectl exec fabric-ca-tools -- mkdir -p $PEER_BASE
kubectl exec fabric-ca-tools -- fabric-ca-client enroll -u https://peer0:$CA_PEERPW@$CA_URL -M $PEER_BASE/msp --csr.hosts peer0.$HOSTNAME.$DOMAIN $CA_CLIENT_OPTS

echo "> MSP: splitting certs"
kubectl exec fabric-ca-tools -- ./process_pem.sh $PEER_BASE/msp/cacerts
kubectl exec fabric-ca-tools -- ./process_pem.sh $PEER_BASE/msp/intermediatecerts

echo "> MSP: moving certs and keys"
kubectl exec fabric-ca-tools -- mv $PEER_BASE/msp/keystore/* $PEER_BASE/msp/keystore/priv_sk
kubectl exec fabric-ca-tools -- mv $PEER_BASE/msp/signcerts/* $PEER_BASE/msp/signcerts/peer0.$HOSTNAME.$DOMAIN-cert.pem

echo "> MSP: copy config yaml"
kubectl cp generated_config/config/msp-config.yaml fabric-tools:$PEER_BASE/msp/config.yaml

echo "> enrolling tls"
kubectl exec fabric-ca-tools -- fabric-ca-client enroll -u https://peer0:$CA_PEERPW@$CA_URL --enrollment.profile tls -M ${PEER_BASE}/tls --csr.hosts peer0.$HOSTNAME.$DOMAIN $CA_CLIENT_OPTS

echo "> TLS: splitting certs"
kubectl exec fabric-ca-tools -- ./process_pem.sh $PEER_BASE/tls/tlscacerts
kubectl exec fabric-ca-tools -- ./process_pem.sh $PEER_BASE/tls/tlsintermediatecerts

echo "> TLS: moving certs and keys"
kubectl exec fabric-ca-tools -- cp $PEER_BASE/tls/tlsintermediatecerts/ca.$HOSTNAME.$DOMAIN-cert.pem $PEER_BASE/tls/ca.crt
kubectl exec fabric-ca-tools -- mv $PEER_BASE/tls/signcerts/* $PEER_BASE/tls/server.crt
kubectl exec fabric-ca-tools -- mv $PEER_BASE/tls/keystore/* $PEER_BASE/tls/server.key

echo "> TLS: pushing cert to MSP"
kubectl exec fabric-ca-tools -- mkdir -p $PEER_BASE/msp/tlscacerts
kubectl exec fabric-ca-tools -- cp $PEER_BASE/tls/ca.crt $PEER_BASE/msp/tlscacerts/tlsca.$HOSTNAME.$DOMAIN-cert.pem

kubectl exec fabric-ca-tools -- mkdir -p $PEER_DIR/config
kubectl cp generated_config/config/configtx.yaml fabric-ca-tools:/$PEER_DIR/config
kubectl exec fabric-ca-tools -- FABRIC_CFG_PATH=$PEER_DIR/config; configtxgen -printOrg
exit;



    mkdir ./tmp
    generateFromTemplate ca-config $ORG $HOSTNAME $DOMAIN $PORT $PEER_BASE > ./tmp/configtx.yaml
    export FABRIC_CFG_PATH=$PWD/tmp
    CONF=${PV_PATH}${MYHOST}-pv-volume/peer/${ORG}.json
    ./bin/configtxgen -printOrg ${ORG}MSP > ./tmp/${ORG}.json
    EXEC="jq '.values += {\"AnchorPeers\":{\"mod_policy\": \"Admins\",\"value\":{\"anchor_peers\": [{\"host\": \"peer0.$HOSTNAME.$DOMAIN\",\"port\": $PORT}]},\"version\": \"0\"}}' ./tmp/$ORG.json > $CONF"
    eval "${EXEC}"
    echo
    rm -rf ./tmp

    ./bin/fabric-ca-client register --caname ca.${HOSTNAME}.${DOMAIN} --id.name ${HOSTNAME}admin --id.secret ${HOSTNAME}${CA_ADMINPW} --id.type admin -H ${FABRIC_CA_HOME} --tls.certfiles ${FABRIC_CA_TLS}


    ADMIN_BASE="${PV_PATH}${MYHOST}-pv-volume/peer/users/Admin@${HOSTNAME}.${DOMAIN}/"

    mkdir -p ${ADMIN_BASE}

    ./bin/fabric-ca-client enroll -u https://${HOSTNAME}admin:${HOSTNAME}${CA_ADMINPW}@ca-${MYHOST}.${KUBENS}:${CA_PORT} --caname ca.${HOSTNAME}.${DOMAIN} -H ${FABRIC_CA_HOME} -M ${ADMIN_BASE}msp --tls.certfiles ${FABRIC_CA_TLS}

    process_pem "${ADMIN_BASE}msp/cacerts/"
    process_pem "${ADMIN_BASE}msp/intermediatecerts/"
#    mkdir ${ADMIN_BASE}msp/chaincerts/
#    mv ${ADMIN_BASE}msp/cacerts/* ${ADMIN_BASE}msp/chaincerts/
#    mv ${ADMIN_BASE}msp/intermediatecerts/* ${ADMIN_BASE}msp/chaincerts/
#    cp ${ADMIN_BASE}msp/chaincerts/ca.${HOSTNAME}.${DOMAIN}-cert.pem ${ADMIN_BASE}msp/cacerts/
    mv ${ADMIN_BASE}msp/keystore/* ${ADMIN_BASE}msp/keystore/priv_sk
    mv ${ADMIN_BASE}msp/signcerts/* ${ADMIN_BASE}msp/signcerts/Admin@${HOSTNAME}.${DOMAIN}-cert.pem

    #config.yaml links to cacerts/ca.${HOSTNAME}.${DOMAIN}-cert.pem
    generateFromTemplate config $HOSTNAME $DOMAIN > "${ADMIN_BASE}msp/config.yaml"

    ./bin/fabric-ca-client enroll -u https://${HOSTNAME}admin:${HOSTNAME}${CA_ADMINPW}@ca-${MYHOST}.${KUBENS}:${CA_PORT} --enrollment.profile tls --caname ca.${HOSTNAME}.${DOMAIN} -H ${FABRIC_CA_HOME} -M ${ADMIN_BASE}tls --tls.certfiles ${FABRIC_CA_TLS}
    process_pem "${ADMIN_BASE}tls/tlscacerts/"
    process_pem "${ADMIN_BASE}tls/tlsintermediatecerts/"
    cp ${ADMIN_BASE}tls/tlsintermediatecerts/ca.${HOSTNAME}.${DOMAIN}-cert.pem ${ADMIN_BASE}tls/ca.crt
    mv ${ADMIN_BASE}tls/signcerts/* ${ADMIN_BASE}tls/server.crt
    mv ${ADMIN_BASE}tls/keystore/* ${ADMIN_BASE}tls/server.key

    #push TLS to MSP
    mkdir ${ADMIN_BASE}msp/tlscacerts
    cp ${ADMIN_BASE}tls/ca.crt ${ADMIN_BASE}msp/tlscacerts/tlsca.${HOSTNAME}.${DOMAIN}-cert.pem
    echo
    echo
    echo "Send this [${CONF}] to DLT Administrator"
    echo
fi
echo
echo
echo "Step 4 [Deploy Peer0]"
generateFromTemplate org $MYHOST $HOSTNAME $DOMAIN $PORT $ORG $KUBENS peer0 $(hostname -i) > ${MYHOST}-peer0.yaml

mkdir -p ${PV_PATH}${MYHOST}-pv-volume/peer/home/
generateFromTemplate peer_start $PORT > ${PV_PATH}${MYHOST}-pv-volume/peer/home/peer_start.sh
chmod a+x ${PV_PATH}${MYHOST}-pv-volume/peer/home/peer_start.sh

echo "  Kubernetes Pod file [${MYHOST}-peer0.yaml] created."
echo "  Apply generated deployment files to your cluster"
echo "  'kubectl apply -f ${MYHOST}-peer0.yaml'"
echo
echo "  wait for 5 seconds, and exec './cli.sh peer channel list'"
echo "  you should see ' Endorser and orderer connections initialized Channels peers has joined:'"
echo
echo "  Wait for further instruction from DLT Administrator after they have processed your subscription. (you need to send the JSON file)"
echo


