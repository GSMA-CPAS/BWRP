#!/bin/bash
. setup.cfg

export PATH=${BASE}bin:${BASE}:$PATH

export ORDERER_CA=$(pwd)/certs/gsma/orderer/tlsca.orderer.hldid.org-cert.pem
export ORDERER_MTLS_CRT=$(pwd)/certs/gsma/orderer/mtls.orderer.hldid.org-cert.crt
export ORDERER_MTLS_KEY=$(pwd)/certs/gsma/orderer/mtls.orderer.hldid.org-key.key

echo $CFG_CONFIG_PATH_PVC
PEER_PATH=$(pwd)/$CFG_CONFIG_PATH_PVC/ca
echo $PEER_PATH

export FABRIC_LOGGING_SPEC=DEBUG
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=${CFG_ORG}MSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PEER_PATH/peers/$CFG_PEER_NAME.$CFG_HOSTNAME.$CFG_DOMAIN/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PEER_PATH/users/Admin@$CFG_HOSTNAME.$CFG_DOMAIN/msp
export CORE_PEER_TLS_CLIENTAUTHREQUIRED=true
export CORE_PEER_TLS_CLIENTCERT_FILE=$PEER_PATH/users/Admin@$CFG_HOSTNAME.$CFG_DOMAIN/msp/signcerts/Admin@$CFG_HOSTNAME.$CFG_DOMAIN-cert.pem
export CORE_PEER_TLS_CLIENTKEY_FILE=$PEER_PATH/users/Admin@$CFG_HOSTNAME.$CFG_DOMAIN/msp/keystore/priv_sk
export CORE_PEER_ADDRESS=$CFG_PEER_NAME.$CFG_HOSTNAME.$CFG_DOMAIN:$CFG_PEER_PORT
export FABRIC_CFG_PATH=$CFG_CONFIG_PATH/config


AUTH="--tls --cafile $ORDERER_CA  --clientauth --certfile $ORDERER_MTLS_CRT --keyfile $ORDERER_MTLS_KEY"
CMD=$@

echo "Setting ENV Variables"
env | grep CORE
env | grep ORDERER
echo 

CMD2=$(echo "${CMD}"|awk '//{gsub("{", "'"'"'{"); gsub("}", "}'"'"'"); gsub("\\^", "\""); gsub("ORDAUTH", "${AUTH}");  print}')
set -x
##eval "${CMD2}"
echo ${CMD2}
set +x
echo 
