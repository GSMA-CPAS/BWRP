#!/bin/bash
# abort processing on the first error
set -e -o pipefail

# load config
. setup.cfg

CA_URL="ca-$CFG_MYHOST.$CFG_KUBENS:$CFG_CA_PORT"
CA_ROOT_DIR="/mnt/data/CA"
CA_CLIENT_DIR="/mnt/data/ca-client"
CA_CLIENT_OPTS="--caname ca.$CFG_HOSTNAME.$CFG_DOMAIN -H $CA_CLIENT_DIR --tls.certfiles $CA_ROOT_DIR/tls-cert.pem"

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

if false; then

echo "> removing peer certificates [FIXME: REMOVE THIS, JUST FOR DEBUG]"
kubectl exec fabric-ca-tools -- rm -rf $CFG_PEER_BASE

echo "> deploying helper script"
kubectl cp process_pem.sh fabric-ca-tools:/opt

echo "> enrolling admin user"
kubectl exec fabric-ca-tools -- fabric-ca-client enroll -u https://admin:$CFG_CA_ADMINPW@$CA_URL $CA_CLIENT_OPTS
echo "> register peer0 user"
#kubectl exec fabric-ca-tools -- fabric-ca-client register --id.name peer0 --id.secret $CFG_CA_PEERPW --id.type peer $CA_CLIENT_OPTS | sed 's|Password: \(.*\)|Password: *** hidden ***\r|'
echo "> enrolling peer0 user"
#kubectl exec fabric-ca-tools -- mkdir -p $PEER_BASE
kubectl exec fabric-ca-tools -- fabric-ca-client enroll -u https://peer0:$CFG_CA_PEERPW@$CA_URL -M $CFG_PEER_BASE/msp --csr.hosts peer0.$CFG_HOSTNAME.$CFG_DOMAIN $CA_CLIENT_OPTS

echo "> MSP: splitting certs"
kubectl exec fabric-ca-tools -- /opt/process_pem.sh $CFG_PEER_BASE/msp/cacerts
kubectl exec fabric-ca-tools -- /opt/process_pem.sh $CFG_PEER_BASE/msp/intermediatecerts

echo "> MSP: moving certs and keys"
kubectl exec fabric-ca-tools -- sh -c "mv $CFG_PEER_BASE/msp/keystore/* $CFG_PEER_BASE/msp/keystore/priv_sk"
kubectl exec fabric-ca-tools -- sh -c "mv $CFG_PEER_BASE/msp/signcerts/* $CFG_PEER_BASE/msp/signcerts/peer0.$CFG_HOSTNAME.$CFG_DOMAIN-cert.pem"

echo "> MSP: copy config yaml"
kubectl cp $CFG_CONFIG_PATH/config/msp-config.yaml fabric-tools:$CFG_PEER_BASE/msp/config.yaml

echo "> enrolling tls"
kubectl exec fabric-ca-tools -- fabric-ca-client enroll -u https://peer0:$CFG_CA_PEERPW@$CA_URL --enrollment.profile tls -M $CFG_PEER_BASE/tls --csr.hosts peer0.$CFG_HOSTNAME.$CFG_DOMAIN $CA_CLIENT_OPTS

echo "> TLS: splitting certs"
kubectl exec fabric-ca-tools -- /opt/process_pem.sh $CFG_PEER_BASE/tls/tlscacerts
kubectl exec fabric-ca-tools -- /opt/process_pem.sh $CFG_PEER_BASE/tls/tlsintermediatecerts

echo "> TLS: moving certs and keys"
kubectl exec fabric-ca-tools -- cp $CFG_PEER_BASE/tls/tlsintermediatecerts/ca.$CFG_HOSTNAME.$CFG_DOMAIN-cert.pem $CFG_PEER_BASE/tls/ca.crt
kubectl exec fabric-ca-tools -- sh -c "mv $CFG_PEER_BASE/tls/signcerts/* $CFG_PEER_BASE/tls/server.crt"
kubectl exec fabric-ca-tools -- sh -c "mv $CFG_PEER_BASE/tls/keystore/* $CFG_PEER_BASE/tls/server.key"

echo "> TLS: pushing cert to MSP"
kubectl exec fabric-ca-tools -- mkdir -p $CFG_PEER_BASE/msp/tlscacerts
kubectl exec fabric-ca-tools -- cp $CFG_PEER_BASE/tls/ca.crt $CFG_PEER_BASE/msp/tlscacerts/tlsca.$CFG_HOSTNAME.$CFG_DOMAIN-cert.pem

echo "> running configtxgen"
kubectl exec fabric-tools -- mkdir -p $CFG_PEER_DIR
kubectl cp $CFG_CONFIG_PATH/config/configtx.yaml fabric-ca-tools:/$CFG_PEER_DIR
fi
kubectl exec fabric-tools -- sh -c "echo \".values += {\\\"AnchorPeers\\\":{\\\"mod_policy\\\":\\\"Admins\\\",\\\"value\\\":{\\\"anchor_peers\\\":[{\\\"host\\\":\\\"peer0.$CFG_HOSTNAME.$CFG_DOMAIN\\\",\\\"port\\\":\\\"$CFG_PEER_PORT\\\"}]},\\\"version\\\":\\\"0\\\"}}\" > $CFG_PEER_DIR/.$CFG_ORG.jq"
kubectl exec fabric-tools -- cat $CFG_PEER_DIR/.$CFG_ORG.jq 
kubectl exec fabric-tools -- sh -c "FABRIC_CFG_PATH=$CFG_PEER_DIR; configtxgen -printOrg ${CFG_ORG}MSP | jq -f $CFG_PEER_DIR/.$CFG_ORG.jq > $CFG_PEER_DIR/$CFG_ORG.json"
exit;




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


