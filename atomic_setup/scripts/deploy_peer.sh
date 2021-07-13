#!/bin/bash
# abort processing on the first error
set -e -o pipefail

# load config
. setup.cfg

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

echo "> copy external builders scripts and config to pvc"
kubectl exec fabric-ca-tools -- mkdir -p /mnt/data/peer/builders/external
kubectl cp scripts/builders/bin fabric-ca-tools:/mnt/data/peer/builders/external/
kubectl cp $CFG_CONFIG_PATH/config/core.yaml fabric-ca-tools:/mnt/data/peer/

echo "> copy peer script to pvc"
chmod +x $CFG_CONFIG_PATH/scripts/peer_start.sh
kubectl exec fabric-ca-tools -- mkdir -p /mnt/data/peer/home
kubectl cp $CFG_CONFIG_PATH/scripts/peer_start.sh fabric-ca-tools:/mnt/data/peer/home

echo "> deploying hyperledger pod"
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/hyperledger-pod.yaml

echo "> deploying hyperledger svc"
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/hyperledger-svc.yaml