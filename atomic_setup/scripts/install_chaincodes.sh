#!/bin/bash
set -e -o pipefail
. setup.cfg 

POD=fabric-tools
LABEL=hybrid_v0.3

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
    echo $(kubectl exec $POD -- /opt/remote_cli.sh peer lifecycle chaincode queryinstalled)
    #if [ $(kubectl exec $POD -- /opt/remote_cli.sh peer lifecycle chaincode)]
    kubectl exec $POD -- /opt/remote_cli.sh peer lifecycle chaincode install /opt/$CHAINCODE.tar.gz
    echo $(kubectl exec $POD -- /opt/remote_cli.sh peer lifecycle chaincode queryinstalled)
}

deploy $CFG_CHAINCODE_NAME chaincode/$CFG_CHAINCODE_NAME/ golang $LABEL false

