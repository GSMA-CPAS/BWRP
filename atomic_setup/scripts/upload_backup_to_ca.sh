#!/bin/bash
# abort processing on the first error
set -e -o pipefail

# load config
. setup.cfg

echo "> uploading CA config backup to pod..."
kubectl exec fabric-ca-tools -- rm -rf $CFG_PEER_DIR
kubectl cp $CFG_CONFIG_PATH_PVC/ca fabric-ca-tools:$CFG_PEER_DIR

