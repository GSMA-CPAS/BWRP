#!/bin/bash
. setup.sh

export PATH=${BASE}bin:${BASE}:$PATH
export ORDERER_CA=${BASE}peer/organizations/ordererOrganizations/hldid.org/orderers/orderer.hldid.org/msp/tlscacerts/tlsca.hldid.org-cert.pem

#export FABRIC_LOGGING_SPEC=DEBUG
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=${ORG}MSP
export CORE_PEER_TLS_ROOTCERT_FILE=${PV_PATH}${MYHOST}-pv-volume/peer/peers/peer0.${HOSTNAME}.${DOMAIN}/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PV_PATH}${MYHOST}-pv-volume/peer/users/Admin@${HOSTNAME}.${DOMAIN}/msp
export CORE_PEER_ADDRESS=peer0.${HOSTNAME}.${DOMAIN}:${PORT}
export FABRIC_CFG_PATH=template

CMD=$@

echo "Setting ENV Variables"
env | grep CORE
env | grep ORDERER
echo 

CMD2=$(echo "${CMD}"|awk '//{gsub("{", "'"'"'{"); gsub("}", "}'"'"'"); gsub("\\^", "\"");  print}')
set -x
eval "${CMD2}"
set +x
echo 
