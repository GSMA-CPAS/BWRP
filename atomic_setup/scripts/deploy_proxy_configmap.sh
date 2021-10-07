#!/bin/bash
# abort processing on the first error
set -e -o pipefail

# load config
. setup.cfg

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS
kubectl create -f $CFG_CONFIG_PATH/kubernetes/namespace.yaml || echo "namespace exists, not deploying"

echo "> applying proxy configmap"
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/proxy-environment-variables.yaml -n $CFG_KUBENS