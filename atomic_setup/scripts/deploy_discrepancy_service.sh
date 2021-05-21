#!/bin/bash
# abort processing on the first error
set -e -o pipefail

# load config
. setup.cfg

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

echo "> apply deployment of discrepancy-service pod"
kubectl apply -f deployment/kubernetes/discrepancy-service-pod.yaml

echo "> apply deployment of discrepancy-service service"
kubectl apply -f deployment/kubernetes/discrepancy-service-svc.yaml

