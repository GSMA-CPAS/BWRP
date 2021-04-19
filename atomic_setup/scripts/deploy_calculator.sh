#!/bin/bash
# abort processing on the first error
set -e -o pipefail

# load config
. setup.cfg

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

echo "> apply deployment of calculator pod"
kubectl apply -f deployment/kubernetes/calculator-pod.yaml

echo "> apply deployment of calculator service"
kubectl apply -f deployment/kubernetes/calculator-svc.yaml

