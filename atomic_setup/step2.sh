#!/bin/bash
. setup.sh



function generateFromTemplate {
  TYPE=$1
  shift

  if [[ "$TYPE" == "config" ]]; then
    sed -e "s/\${HOSTNAME}/$1/g" \
        -e "s/\${DOMAIN}/$2/g" \
        template/template-config.yaml
  elif [[ "$TYPE" == "ca-config" ]]; then
    base=`echo "${5}" | awk '{gsub(/\//, "\\\/");  print}'`
    sed -e "s/\${ORG}/$1/g" \
        -e "s/\${HOSTNAME}/$2/g" \
        -e "s/\${DOMAIN}/$3/g" \
        -e "s/\${PORT}/$4/g" \
        -e "s/\${PEER_BASE}/$base/g" \
        template/template-configtx.yaml
  elif [[ "$TYPE" == "org" ]]; then
    sed -e "s/\${MYHOST}/$1/g" \
        -e "s/\${HOSTNAME}/$2/g" \
        -e "s/\${DOMAIN}/$3/g" \
        -e "s/\${PORT}/$4/g" \
        -e "s/\${ORG}/$5/g" \
        -e "s/\${KUBENS}/$6/g" \
        -e "s/\${MYPEER}/$7/g" \
        -e "s/\${MYHOSTIP}/$8/g" \
        -e "s/\s*#.*$//" \
        -e "/^\s*$/d" \
        template/template-org-pod.yaml
  elif [[ "$TYPE" == "peer_start" ]]; then
    sed -e "s/\${PORT}/$1/g" \
        template/peer_start.sh
  fi

}

HOSTFILE="$(cat /etc/hosts |grep ca-${MYHOST}.local | awk '{print $1}')"
SVCHOST=$(kubectl get svc --selector=io.kompose.service=ca-${MYHOST} -o=jsonpath={.items[*].spec.clusterIP} -n $KUBENS)

if [ "$HOSTFILE" != "$SVCHOST" ] && [ "$HOSTFILE" != "" ]; then
   echo "WARN> Host config [/etc/hosts] for 'ca-${MYHOST}.local' or mismatch"
   echo "      Please fix and try again."
   echo
   cat /etc/hosts
   echo
   kubectl get svc --selector=io.kompose.service=ca-${MYHOST} -o=wide -n $KUBENS
   echo
   exit 0
fi


echo "Step 3 [Generate Certs for Peer]"
FABRIC_CA_TLS="${PV_PATH}${MYHOST}-pv-volume/CA/tls-cert.pem"
FABRIC_CA_HOME="./fabric-ca-client/"
PEER_BASE="${PV_PATH}${MYHOST}-pv-volume/peer/peers/peer0.${HOSTNAME}.${DOMAIN}/"


if [ -d "${PV_PATH}${MYHOST}-pv-volume/peer/peers/peer0.${HOSTNAME}.${DOMAIN}/" ] || [ -d "${PV_PATH}${MYHOST}-pv-volume/peer/users/Admin@${HOSTNAME}.${DOMAIN}/" ]; then
    if [ -d "${PV_PATH}${MYHOST}-pv-volume/peer/peers/peer0.${HOSTNAME}.${DOMAIN}/" ]; then
        echo "  Existing Certs found [${PV_PATH}${MYHOST}-pv-volume/peer/peers/peer0.${HOSTNAME}.${DOMAIN}/]. Not creating new one."
        echo "  To re-generate, please remove the exiting file."
        echo "  rm -rf ${PV_PATH}${MYHOST}-pv-volume/peer/peers/peer0.${HOSTNAME}.${DOMAIN}/"
        echo
    fi
    if [ -d "${PV_PATH}${MYHOST}-pv-volume/peer/users/Admin@${HOSTNAME}.${DOMAIN}/" ]; then
        echo "  Existing Certs found [${PV_PATH}${MYHOST}-pv-volume/peer/users/Admin@${HOSTNAME}.${DOMAIN}/]. Not creating new one."
        echo "  To re-generate, please remove the exiting file."
        echo "  rm -rf ${PV_PATH}${MYHOST}-pv-volume/peer/users/Admin@${HOSTNAME}.${DOMAIN}/"
        echo
    fi
    read -n 1 -p "Press [Y] to continue or any key to stop:`echo $'\n> '`" sel
    if [[ "$sel" != "y" ]] && [[ "$sel" != "Y" ]]; then
          echo
          exit 0
    fi
else 
    ./bin/fabric-ca-client enroll -u https://admin:${CA_ADMINPW}@ca-${MYHOST}.local:${CA_PORT} --caname ca.${HOSTNAME}.${DOMAIN} -H ${FABRIC_CA_HOME} --tls.certfiles ${FABRIC_CA_TLS}
    ./bin/fabric-ca-client register --caname ca.${HOSTNAME}.${DOMAIN} --id.name peer0 --id.secret peer0${CA_ADMINPW} --id.type peer -H ${FABRIC_CA_HOME} --tls.certfiles ${FABRIC_CA_TLS}

    mkdir -p ${PEER_BASE}
    ./bin/fabric-ca-client enroll -u https://peer0:peer0${CA_ADMINPW}@ca-${MYHOST}.local:${CA_PORT} --caname ca.${HOSTNAME}.${DOMAIN} -H ${FABRIC_CA_HOME} -M ${PEER_BASE}msp --csr.hosts peer0.${HOSTNAME}.${DOMAIN} --tls.certfiles ${FABRIC_CA_TLS}

    mv ${PEER_BASE}msp/cacerts/* ${PEER_BASE}msp/cacerts/ca.${HOSTNAME}.${DOMAIN}-cert.pem
    mv ${PEER_BASE}msp/keystore/* ${PEER_BASE}msp/keystore/priv_sk
    mv ${PEER_BASE}msp/signcerts/* ${PEER_BASE}msp/signcerts/peer0.${HOSTNAME}.${DOMAIN}-cert.pem

    #config.yaml links to cacerts/ca.${HOSTNAME}.${DOMAIN}-cert.pem
    echo "$(generateFromTemplate config $HOSTNAME $DOMAIN)" > "${PEER_BASE}msp/config.yaml"


    ./bin/fabric-ca-client enroll -u https://peer0:peer0${CA_ADMINPW}@ca-${MYHOST}.local:${CA_PORT} --enrollment.profile tls --caname ca.${HOSTNAME}.${DOMAIN} -H ${FABRIC_CA_HOME} -M ${PEER_BASE}tls --csr.hosts peer0.${HOSTNAME}.${DOMAIN} --tls.certfiles ${FABRIC_CA_TLS}
    mv ${PEER_BASE}tls/tlscacerts/* ${PEER_BASE}tls/ca.crt
    mv ${PEER_BASE}tls/signcerts/* ${PEER_BASE}tls/server.crt
    mv ${PEER_BASE}tls/keystore/* ${PEER_BASE}tls/server.key

    #push TLS to MSP
    mkdir -p ${PEER_BASE}msp/tlscacerts/
    cp ${PEER_BASE}tls/ca.crt ${PEER_BASE}msp/tlscacerts/tlsca.${HOSTNAME}.${DOMAIN}-cert.pem


    mkdir ./tmp
    echo "$(generateFromTemplate ca-config $ORG $HOSTNAME $DOMAIN $PORT $PEER_BASE)" > ./tmp/configtx.yaml
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

    ./bin/fabric-ca-client enroll -u https://${HOSTNAME}admin:${HOSTNAME}${CA_ADMINPW}@ca-${MYHOST}.local:${CA_PORT} --caname ca.${HOSTNAME}.${DOMAIN} -H ${FABRIC_CA_HOME} -M ${ADMIN_BASE}msp --tls.certfiles ${FABRIC_CA_TLS}

    mv ${ADMIN_BASE}msp/cacerts/* ${ADMIN_BASE}msp/cacerts/ca.${HOSTNAME}.${DOMAIN}-cert.pem
    mv ${ADMIN_BASE}msp/keystore/* ${ADMIN_BASE}msp/keystore/priv_sk
    mv ${ADMIN_BASE}msp/signcerts/* ${ADMIN_BASE}msp/signcerts/Admin@${HOSTNAME}.${DOMAIN}-cert.pem

    #config.yaml links to cacerts/ca.${HOSTNAME}.${DOMAIN}-cert.pem
    echo "$(generateFromTemplate config $HOSTNAME $DOMAIN)" > "${ADMIN_BASE}msp/config.yaml"

    ./bin/fabric-ca-client enroll -u https://${HOSTNAME}admin:${HOSTNAME}${CA_ADMINPW}@ca-${MYHOST}.local:${CA_PORT} --enrollment.profile tls --caname ca.${HOSTNAME}.${DOMAIN} -H ${FABRIC_CA_HOME} -M ${ADMIN_BASE}tls --tls.certfiles ${FABRIC_CA_TLS}

    mv ${ADMIN_BASE}tls/tlscacerts/* ${ADMIN_BASE}tls/ca.crt
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
echo "$(generateFromTemplate org $MYHOST $HOSTNAME $DOMAIN $PORT $ORG $KUBENS peer0 $(hostname -i))" > ${MYHOST}-peer0.yaml

mkdir -p ${PV_PATH}${MYHOST}-pv-volume/peer/home/
echo "$(generateFromTemplate peer_start $PORT)" > ${PV_PATH}${MYHOST}-pv-volume/peer/home/peer_start.sh
chmod a+x ${PV_PATH}${MYHOST}-pv-volume/peer/home/peer_start.sh

echo "  Kubernetes Pod file [${MYHOST}-peer0.yaml] created."
echo "  Apply generated deployment files to your cluster"
echo "  'kubectl apply -f ${MYHOST}-peer0.yaml'"
echo
echo "  wait for 5 seconds, and exec './cli.sh peer channel list'"
echo "  you should see ' Endorser and orderer connections initialized
Channels peers has joined:'"
echo
echo "  Wait for further instruction from DLT Administrator after they have processed your subscription. (you need to send the JSON file)"
echo


