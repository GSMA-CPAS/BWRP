#!/bin/bash
set -e -o pipefail
. setup.cfg 

POD=fabric-tools
LABEL=offchainHybrid_0.1

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

function deploy() {
    CHAINCODE=$1
    CHAINCODE_DIR=$2
    CHAINCODE_LAN=$3
    CHAINCODE_LABEL=$4
    USE_PREPACKED_CHAINCODE=$5

    if [ "$USE_PREPACKED_CHAINCODE" == "true" ]; then
        echo "> using prepacked chaincode, copying $CHAINCODE.tar.gz to pod"
        kubectl cp chaincode/$CHAINCODE/pkg/$CHAINCODE.tar.gz $POD:/opt
    else
        echo "> copying $CHAINCODE package to pod"
        kubectl cp chaincode $POD:chaincode
        
        echo "> rebuilding chaincode $CHAINCODE"
        kubectl exec $POD -- /opt/remote_cli.sh peer lifecycle chaincode package /opt/$CHAINCODE.tar.gz --path $CHAINCODE_DIR --lang $CHAINCODE_LAN --label $CHAINCODE_LABEL
    fi

    echo "> installing chaincode "
    kubectl exec $POD -- /opt/remote_cli.sh peer lifecycle chaincode install /opt/$CHAINCODE.tar.gz
}

function approve(){
    CHAINCODE_LABEL=$1

    PACKAGE_ID=$(kubectl exec $POD -- /opt/remote_cli.sh peer lifecycle chaincode queryinstalled |grep $CHAINCODE_LABEL)
    PACKAGE_ID="${PACKAGE_ID//Installed chaincodes on peer:/}"
    PACKAGE_ID="${PACKAGE_ID//Package ID: /}"
    PACKAGE_ID="${PACKAGE_ID//, Label: */}"

    INFO=$(kubectl exec $POD -- /opt/remote_cli.sh peer lifecycle chaincode querycommitted -o orderer.hldid.org:7050 --channelID ${CFG_CHANNEL_NAME} --name ${CFG_CHAINCODE_NAME} --output json)

    VERSION=$(echo $INFO | jq -r '.version' )
    SEQUENCE=$(echo $INFO | jq '.sequence' )

    echo "> got package id $PACKAGE_ID"
    echo "> got version $VERSION, sequence $SEQUENCE"

    echo "> approving chaincode "
    kubectl exec $POD -- /opt/remote_cli.sh peer lifecycle chaincode approveformyorg --channelID ${CFG_CHANNEL_NAME} --name ${CFG_CHAINCODE_NAME} --version $VERSION --package-id $PACKAGE_ID --sequence $SEQUENCE -o orderer.hldid.org:7050 --tls --cafile /opt/certs/tlsca.orderer.hldid.org-cert.pem --clientauth --keyfile /mnt/data/peer/peers/${CFG_PEER_NAME}.${CFG_HOSTNAME}.${CFG_DOMAIN}/tls/server.key --certfile /mnt/data/peer/peers/${CFG_PEER_NAME}.${CFG_HOSTNAME}.${CFG_DOMAIN}/tls/server.crt
}

deploy $CFG_CHAINCODE_NAME chaincode/$CFG_CHAINCODE_NAME/ golang $LABEL false
approve $LABEL
