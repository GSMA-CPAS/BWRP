#!/bin/bash
set -e -o pipefail 
. setup.cfg 


echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

USE_PREPACKED_CHAINCODE=true
if [ "$USE_PREPACKED_CHAINCODE" == "true" ]; then
    echo "> using prepacked chaincode, copying counter.tar.gz to pod"
    kubectl cp chaincode/counter/pkg/counter.tar.gz fabric-tools:/opt
else
    echo "> copying counter package to pod"
    kubectl cp chaincode/counter/javascript fabric-tools:/opt/counter_chaincode
    
    echo "> rebuilding chaincode "
    kubectl exec fabric-tools -- /opt/remote_cli.sh peer lifecycle chaincode package /opt/counter.tar.gz --path /opt/counter_chaincode --lang node --label counter_v1
fi

echo "> installing chaincode "
kubectl exec fabric-tools -- /opt/remote_cli.sh peer lifecycle chaincode install /opt/counter.tar.gz
