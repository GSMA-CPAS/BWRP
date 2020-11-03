#!/bin/bash
set -e -o pipefail 

. setup.cfg

CHAINCODE_PACKAGE=offchainHybrid_0.1.tar.gz
TOOLS_POD=fabric-tools
LABEL=offchainHybrid_0.1

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

if [[ -z $(kubectl -n ${CFG_KUBENS} exec $TOOLS_POD -- ls /opt | grep remote_cli.sh) ]]
then
    echo "Preparing remote cli"
    ./scripts/prepare_remote_cli.sh
fi

if [ -f "chaincode_hybrid/$CHAINCODE_PACKAGE" ]; then
    echo "> using prepacked chaincode, copying chaincode package $CHAINCODE_PACKAGE to the pod"
    kubectl cp chaincode_hybrid/$CHAINCODE_PACKAGE $TOOLS_POD:/opt/
else
    echo "> copying chaincode source to the pod"
    kubectl cp chaincode_hybrid/src $TOOLS_POD:/opt/chaincode_hybrid

    echo "> rebuilding chaincode "
    kubectl -n ${CFG_KUBENS} exec $TOOLS_POD -- /opt/remote_cli.sh peer lifecycle chaincode package /opt/$CHAINCODE_PACKAGE --path chaincode_hybrid/src/ --lang golang --label hybrid_v1
fi

echo "> installing chaincode "
kubectl -n ${CFG_KUBENS} exec $TOOLS_POD -- /opt/remote_cli.sh peer lifecycle chaincode install /opt/$CHAINCODE_PACKAGE

PACKAGE_ID=$(kubectl -n ${CFG_KUBENS} exec $TOOLS_POD -- /opt/remote_cli.sh peer lifecycle chaincode queryinstalled |grep $LABEL)
PACKAGE_ID="${PACKAGE_ID//Installed chaincodes on peer:/}"
PACKAGE_ID="${PACKAGE_ID//Package ID: /}"
PACKAGE_ID="${PACKAGE_ID//, Label: */}"

INFO=$(kubectl -n ${CFG_KUBENS} exec ${TOOLS_POD} -- /opt/remote_cli.sh peer lifecycle chaincode querycommitted -o orderer.hldid.org:7050 --channelID ${CFG_CHANNEL_NAME} --name ${CFG_CHAINCODE_NAME} --output json)

VERSION=$(echo $INFO | jq -r '.version' )
SEQUENCE=$(echo $INFO | jq '.sequence' )

echo "> approveing chaincode "
kubectl -n ${CFG_KUBENS} exec ${TOOLS_POD} -- /opt/remote_cli.sh peer lifecycle chaincode approveformyorg --channelID ${CFG_CHANNEL_NAME} --name ${CFG_CHAINCODE_NAME} --version ${VERSION} --package-id ${PACKAGE_ID} --sequence ${SEQUENCE} -o orderer.hldid.org:7050 --tls --cafile /opt/certs/tlsca.orderer.hldid.org-cert.pem --clientauth --keyfile /mnt/data/peer/peers/${CFG_PEER_NAME}.${CFG_HOSTNAME}.${CFG_DOMAIN}/tls/server.key --certfile /mnt/data/peer/peers/${CFG_PEER_NAME}.${CFG_HOSTNAME}.${CFG_DOMAIN}/tls/server.crt