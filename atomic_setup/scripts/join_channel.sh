#!/bin/bash
set -e -o pipefail 

if [ "$#" -ne 1 ]; then
    echo "> usage: $0 <channel name>"
    exit 1
fi

CHANNEL=$1

. setup.cfg 

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

echo "> fetching joined channels: "
JOINED_CHANNELS=$(kubectl exec fabric-tools -- /opt/remote_cli.sh peer channel list | awk '{if(found) print} /Channels peers has joined/{found=1}' | xargs)
echo "> currently joined: [$JOINED_CHANNELS]"

if [ $(echo $JOINED_CHANNELS | grep -wc $CHANNEL) -ge 1 ]; then
    echo "> already joined to channel, not joining again...";
    exit 0
fi;

echo "> fetching block 0"
kubectl exec fabric-tools -- /opt/remote_cli.sh peer channel fetch 0 $CHANNEL.block -c $CHANNEL -o orderer.hldid.org:7050

echo "> joining channel"
kubectl exec fabric-tools -- /opt/remote_cli.sh peer channel join -b $CHANNEL.block

echo "> listing joined channels: "
kubectl exec fabric-tools -- /opt/remote_cli.sh peer channel list
