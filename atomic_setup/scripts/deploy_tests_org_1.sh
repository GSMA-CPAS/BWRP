#!/bin/bash
set -e -o pipefail

# load config
. setup.cfg

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

echo "> creating test dir"
kubectl -n $CFG_KUBENS exec fabric-tools -- mkdir -p /opt/test

echo "> upload configs"
kubectl -n $CFG_KUBENS cp ./tests/test_setup.cfg fabric-tools:/opt/test/

echo "> upload test 1"
kubectl -n $CFG_KUBENS cp ./tests/test_1_org_1.sh fabric-tools:/opt/test/

echo "> upload test 2"
kubectl -n $CFG_KUBENS cp ./tests/test_3_org_1.sh fabric-tools:/opt/test/

echo "> upload test 3"
kubectl -n $CFG_KUBENS cp ./tests/test_5_org_1.sh fabric-tools:/opt/test/

echo "> installing needed packages"
kubectl -n $CFG_KUBENS exec fabric-tools -- apk update
kubectl -n $CFG_KUBENS exec fabric-tools -- apk add jq curl openssl

echo "> tests are uploaded in fabric-tools:/opt/test/"
