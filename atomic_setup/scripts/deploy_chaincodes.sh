#!/bin/bash
set -e -o pipefail 
. setup.cfg 


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
        kubectl cp chaincode/$CHAINCODE/pkg/$CHAINCODE.tar.gz fabric-tools:/opt
    else
        echo "> copying $CHAINCODE package to pod"
        kubectl cp chaincode fabric-tools:chaincode
        
        echo "> rebuilding chaincode $CHAINCODE"
        kubectl exec fabric-tools -- /opt/remote_cli.sh peer lifecycle chaincode package /opt/$CHAINCODE.tar.gz --path $CHAINCODE_DIR --lang $CHAINCODE_LAN --label $CHAINCODE_LABEL
    fi

    echo "> installing chaincode "
    kubectl exec fabric-tools -- /opt/remote_cli.sh peer lifecycle chaincode install /opt/$CHAINCODE.tar.gz
}

#deploy counter chaincode/counter/javascript/ node counter_v1 true
deploy hybrid  chaincode/hybrid/ golang offchainHybrid_0.1 false
