#!/bin/bash
. setup.sh

export PATH=${BASE}bin:${BASE}:$PATH

export ORDERER_CA=$(pwd)/tlsca.orderer.hldid.org-cert.pem
export ORDERER_MTLS_CRT=$(pwd)/mtls.orderer.hldid.org-cert.crt
export ORDERER_MTLS_KEY=$(pwd)/mtls.orderer.hldid.org-key.key

#export FABRIC_LOGGING_SPEC=DEBUG
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=${ORG}MSP
export CORE_PEER_TLS_ROOTCERT_FILE=${PV_PATH}${MYHOST}-pv-volume/peer/peers/peer0.${HOSTNAME}.${DOMAIN}/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PV_PATH}${MYHOST}-pv-volume/peer/users/Admin@${HOSTNAME}.${DOMAIN}/msp
export CORE_PEER_TLS_CLIENTAUTHREQUIRED=true
export CORE_PEER_TLS_CLIENTCERT_FILE=${PV_PATH}${MYHOST}-pv-volume/peer/users/Admin@${HOSTNAME}.${DOMAIN}/msp/signcerts/Admin@${HOSTNAME}.${DOMAIN}-cert.pem
export CORE_PEER_TLS_CLIENTKEY_FILE=${PV_PATH}${MYHOST}-pv-volume/peer/users/Admin@${HOSTNAME}.${DOMAIN}/msp/keystore/priv_sk
export CORE_PEER_ADDRESS=peer0.${HOSTNAME}.${DOMAIN}:${PORT}
export FABRIC_CFG_PATH=template


AUTH="--tls --cafile $ORDERER_CA  --clientauth --certfile $ORDERER_MTLS_CRT --keyfile $ORDERER_MTLS_KEY"
CMD=$@

echo "Setting ENV Variables"
env | grep CORE
env | grep ORDERER
echo 

CMD2=$(echo "${CMD}"|awk '//{gsub("{", "'"'"'{"); gsub("}", "}'"'"'"); gsub("\\^", "\""); gsub("ORDAUTH", "${AUTH}");  print}')
set -x
eval "${CMD2}"
set +x
echo 
