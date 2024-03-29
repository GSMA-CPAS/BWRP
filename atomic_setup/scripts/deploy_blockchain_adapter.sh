#!/bin/bash
# abort processing on the first error
set -e -o pipefail

# load config
. setup.cfg

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

echo "> upload setup_offchain_endpoint.sh and setup_sign_certs.sh"
kubectl cp $CFG_CONFIG_PATH/scripts/setup_offchain_endpoint.sh fabric-tools:/opt/
kubectl cp $CFG_CONFIG_PATH/scripts/setup_sign_certs.sh fabric-tools:/opt/

echo "> upload ccp"
kubectl -n $CFG_KUBENS exec fabric-ca-tools -- mkdir -p /mnt/data/CCP/wallet
kubectl -n $CFG_KUBENS cp $CFG_CONFIG_PATH/config/ccp/${CFG_ORG}.json fabric-ca-tools:/mnt/data/CCP/${CFG_ORG}.json
kubectl -n $CFG_KUBENS cp $CFG_CONFIG_PATH/config/ccp/wallet fabric-ca-tools:/mnt/data/CCP/

echo "> deploying blockchain-adapter pod and svc"
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/blockchain-adapter-svc.yaml
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/blockchain-adapter-pod.yaml

echo "> waiting for blockchain-adapter pod to be ready"
POD=$(kubectl -n $CFG_KUBENS get pods | grep ^blockchain-adapter- | awk '{print $1}')
kubectl wait --timeout=5m --for=condition=ready pod/$POD

echo "setup offchain endpoint and sign certs"
kubectl exec fabric-tools -- apk update
kubectl exec fabric-tools -- apk add curl
kubectl exec fabric-tools -- bash /opt/setup_offchain_endpoint.sh
kubectl exec fabric-tools -- bash /opt/setup_sign_certs.sh

echo "> all done."
