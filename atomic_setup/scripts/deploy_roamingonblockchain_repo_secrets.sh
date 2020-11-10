#!/bin/bash
# abort processing on the first error
set -e -o pipefail

# load config
. setup.cfg

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

echo "> apply docker secrets for roamingonblockchain repo"
kubectl apply -f deployment/kubernetes/registry-secret.yaml

