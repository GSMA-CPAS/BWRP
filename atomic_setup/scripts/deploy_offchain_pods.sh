#!/bin/bash
# abort processing on the first error
set -e -o pipefail

# load config
. setup.cfg

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

echo "> deploying offchain-db pod and svc"
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/offchain-db-svc.yaml
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/offchain-db-pod.yaml

echo "> waiting for offchain-db pod to be ready"
POD=$(kubectl -n $CFG_KUBENS get pods | grep ^offchain-db- | grep -v  ^offchain-db-adapter- | awk '{print $1}')
kubectl wait --timeout=5m --for=condition=ready pod/$POD

echo "> deploying offchain-db-adapter pod and svc"
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/offchain-db-adapter-svc.yaml
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/offchain-db-adapter-pod.yaml

echo "> waiting for offchain-db-adapter pod to be ready"
POD=$(kubectl -n $CFG_KUBENS get pods | grep ^offchain-db-adapter- | awk '{print $1}')
kubectl wait --timeout=5m --for=condition=ready pod/$POD

echo "> all done."
