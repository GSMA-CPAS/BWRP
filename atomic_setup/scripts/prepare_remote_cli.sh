#!/bin/bash
. setup.cfg
set -e -o pipefail

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

echo "> copying orderer certs to pod"
kubectl exec  fabric-tools -- mkdir -p /opt/certs
kubectl cp certs/gsma/orderer/mtls.orderer.hldid.org-cert.crt fabric-tools:/opt/certs
kubectl cp certs/gsma/orderer/mtls.orderer.hldid.org-key.key fabric-tools:/opt/certs
kubectl cp certs/gsma/orderer/tlsca.orderer.hldid.org-cert.pem fabric-tools:/opt/certs

echo "> copying remote_cli script to pod"
chmod +x $CFG_CONFIG_PATH/scripts/remote_cli.sh
kubectl cp $CFG_CONFIG_PATH/scripts/remote_cli.sh fabric-tools:/opt/remote_cli.sh
