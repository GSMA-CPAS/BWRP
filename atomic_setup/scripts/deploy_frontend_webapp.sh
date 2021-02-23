#!/bin/bash
# abort processing on the first error
set -e -o pipefail

# load config
. setup.cfg

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

echo "> creating dirs..."
kubectl -n $CFG_KUBENS exec fabric-tools -- mkdir -p /mnt/data/WEBAPP/config
kubectl -n $CFG_KUBENS exec fabric-tools -- mkdir -p /mnt/data/WEBAPP/DB
kubectl -n $CFG_KUBENS exec fabric-tools -- mkdir -p /mnt/data/WEBAPP/certs
kubectl -n $CFG_KUBENS exec fabric-tools -- mkdir -p /mnt/data/WEBAPP/wallet
kubectl -n $CFG_KUBENS exec fabric-tools -- chown 100:101 /mnt/data/WEBAPP/wallet

echo "> uploading webapp files..."
kubectl -n $CFG_KUBENS cp $CFG_CONFIG_PATH/config/webapp/production.json fabric-tools:/mnt/data/WEBAPP/config/
kubectl -n $CFG_KUBENS cp $CFG_CONFIG_PATH/config/webapp/custom-environment-variables.json fabric-tools:/mnt/data/WEBAPP/config/

echo "> deploying frontend pod and svc..."
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/webapp-svc.yaml
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/webapp-pod.yaml

echo "> waiting for webapp pod to be ready"
POD=$(kubectl -n $CFG_KUBENS get pods | grep ^webapp- | awk '{print $1}')
kubectl wait --timeout=5m --for=condition=ready pod/$POD

echo "> all done." 
