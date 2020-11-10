#!/bin/bash
set -e -o pipefail

# load config
. setup.cfg

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

echo "> upload config & tests"
kubectl -n $CFG_KUBENS exec fabric-tools -- rm -rf /opt/tests/
kubectl -n $CFG_KUBENS cp ./tests fabric-tools:/opt/tests/

echo "> installing needed packages"
kubectl -n $CFG_KUBENS exec fabric-tools -- apk update
kubectl -n $CFG_KUBENS exec fabric-tools -- apk add jq curl openssl

echo "> tests are uploaded in fabric-tools:/opt/tests/"
