#!/bin/bash
# abort processing on the first error
set -e -o pipefail

# load config
. setup.cfg

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

echo "> apply deployment of common-adapter pod"
kubectl apply -f deployment/kubernetes/common-adapter-pod.yaml

echo "> apply deployment of common-adapter service"
kubectl apply -f deployment/kubernetes/common-adapter-svc.yaml

