#!/bin/bash
set -e -o pipefail

# load config
. setup.cfg

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

#TODO: add timeout?

while true; do
    echo "> get channel height"
    MAX_LEDGERHEIGHT=`kubectl exec fabric-tools -- /opt/remote_discovery.sh | jq '.[].LedgerHeight' | sort -nr | head -n1`

    echo "> get our channel height"
    OUR_LEDGERHEIGHT=`kubectl exec fabric-tools -- /opt/remote_cli.sh peer channel getinfo -c $CFG_CHANNEL_NAME | grep height | sed -e 's/Blockchain info://' | jq .height`

    DIFF=$(($MAX_LEDGERHEIGHT - $OUR_LEDGERHEIGHT))
    echo "> Ledger is at: $MAX_LEDGERHEIGHT , our peer has $OUR_LEDGERHEIGHT, so $DIFF to go"

    if [ "$DIFF" -le "1" ] && [ "$DIFF" -ge "0" ]
        then
        echo "> synced"
        exit 0
    fi
    sleep 10
done
