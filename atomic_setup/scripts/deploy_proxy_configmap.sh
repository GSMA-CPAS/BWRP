#!/bin/bash
# abort processing on the first error
set -e -o pipefail

# load config
. setup.cfg

echo "> applying proxy configmap"
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/proxy-environment-variables.yaml -n $CFG_KUBENS