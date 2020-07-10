#!/bin/bash
set -e -o pipefail 
. setup.cfg 


echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

echo "> listing joined channels: "
kubectl exec fabric-tools -- /opt/remote_cli.sh peer channel list

echo "> fetching block 0"
kubectl exec fabric-tools -- /opt/remote_cli.sh peer channel fetch 0 mychannel.block -c mychannel -o orderer.hldid.org:7050

echo "> joining channel"
kubectl exec fabric-tools -- /opt/remote_cli.sh peer channel join -b mychannel.block

echo "> listing joined channels: "
kubectl exec fabric-tools -- /opt/remote_cli.sh peer channel list
