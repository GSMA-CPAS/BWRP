#!/bin/bash
set -e -o pipefail 
. setup.cfg 


echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS


echo "> copying counter.tgz to pod"
kubectl cp chaincode/counter/javascript fabric-tools:/opt/counter_chaincode

echo "> rebuilding chaincode "
kubectl exec fabric-tools -- /opt/remote_cli.sh peer lifecycle chaincode package counter.tar.gz --path /opt/counter_chaincode --lang node --label counter_v1

echo "> installing chaincode "
kubectl exec fabric-tools -- /opt/remote_cli.sh peer lifecycle chaincode install counter.tar.gz
