#!/bin/bash
set -e -o pipefail 
. setup.cfg 


echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

USE_PREPACKED_CHAINCODE=false
if [ "$USE_PREPACKED_CHAINCODE" == "true" ]; then
    echo "> using prepacked chaincode, copying counter.tar.gz to pod"
    kubectl cp chaincode/counter/pkg/counter.tar.gz fabric-tools:/opt
else
    echo "> copying counter package to pod"
    kubectl cp chaincode fabric-tools:chaincode
    
    echo "> rebuilding chaincode "
    kubectl exec fabric-tools -- /opt/remote_cli.sh peer lifecycle chaincode package /opt/counter.tar.gz --path chaincode/counter/javascript/ --lang node --label counter_v1
fi

echo "> installing chaincode "
kubectl exec fabric-tools -- /opt/remote_cli.sh peer lifecycle chaincode install /opt/counter.tar.gz
