#!/bin/bash
# abort processing on the first error
set -e -o pipefail

. setup.cfg


echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

echo "> deploying fabric-ca-tools container"
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/fabric-ca-tools.yaml
echo "> waiting for pod ready condition"
kubectl wait --timeout=5m --for=condition=ready pod/fabric-ca-tools

echo "> backup and cleaning peer and users certs directories"
kubectl exec fabric-ca-tools -- sh -c "mv $CFG_PEER_DIR/peers/$CFG_PEER_NAME.$CFG_HOSTNAME.$CFG_DOMAIN $CFG_PEER_DIR/peers/$CFG_PEER_NAME.$CFG_HOSTNAME.$CFG_DOMAIN-backup"
kubectl exec fabric-ca-tools -- sh -c "rm -rf $CFG_PEER_DIR/peers/$CFG_PEER_NAME.$CFG_HOSTNAME.$CFG_DOMAIN"
kubectl exec fabric-ca-tools -- sh -c "mv $CFG_PEER_DIR/users/Admin@$CFG_HOSTNAME.$CFG_DOMAIN $CFG_PEER_DIR/users/Admin@$CFG_HOSTNAME.$CFG_DOMAIN-backup"
kubectl exec fabric-ca-tools -- sh -c "rm -rf $CFG_PEER_DIR/users/Admin@$CFG_HOSTNAME.$CFG_DOMAIN"
kubectl exec fabric-ca-tools -- sh -c "mv $CFG_PEER_DIR/users/$CFG_CA_PEER_TLS_USERNAME@$CFG_HOSTNAME.$CFG_DOMAIN $CFG_PEER_DIR/users/$CFG_CA_PEER_TLS_USERNAME@$CFG_HOSTNAME.$CFG_DOMAIN-backup"
kubectl exec fabric-ca-tools -- sh -c "rm -rf $CFG_PEER_DIR/users/$CFG_CA_PEER_TLS_USERNAME@$CFG_HOSTNAME.$CFG_DOMAIN"

./scripts/renew_crypto.sh
./scripts/renew_crypto_mtls.sh

for file in $(ls $CFG_CONFIG_PATH/config/ccp/wallet/*.tpl); do
    echo "> scanning template $file and replacing pem import tags"
    OUTPUT=${file%.tpl}
    echo > $OUTPUT
    while IFS='' read -r line || [[ -n "$line" ]]; do
        fn=$(sed -n -e 's/.*from_pem:\s*\([^ "]*\).*/\1/p' <<< "$line")
        if [ ! -z "$fn" ]; then
            echo "> fetching PEM '$fn'"
            if [ ! -f "$fn" ]; then 
                echo "> ERROR: failed to read file '$fn'";
                exit 1;
            fi;
            # fetch pem and escape chars so that we can feed it into sed
            PEM=$(cat $fn |  awk 1 ORS='\\n' | sed -e 's/[\/&]/\\&/g')
            # do replacement
            sed -e "s/\(.*\)\(from_pem:\s*[^ \"]*\)\(.*\)/\1$PEM\3/" <<< "$line" >> $OUTPUT
        else
            
            # nothing to do
            echo $line >> $OUTPUT
        fi;
    done < "$file"
done

echo "> upload wallets"
kubectl -n $CFG_KUBENS cp $CFG_CONFIG_PATH/config/ccp/wallet fabric-ca-tools:/mnt/data/CCP/

echo "> restart peer and blockchain-adapter pods"

echo "> restarting peer pod and wait it to be ready"
POD=$(kubectl -n $CFG_KUBENS get pods | grep ^peer0- | awk '{print $1}')
kubectl -n $CFG_KUBENS delete pod $POD
POD=$(kubectl -n $CFG_KUBENS get pods | grep ^peer0- | awk '{print $1}')
kubectl wait --timeout=5m --for=condition=ready pod/$POD


echo "> restarting blockchain-adapter pod and wait it to be ready"
POD=$(kubectl -n $CFG_KUBENS get pods | grep ^blockchain-adapter- | awk '{print $1}')
kubectl -n $CFG_KUBENS delete pod $POD
POD=$(kubectl -n $CFG_KUBENS get pods | grep ^blockchain-adapter- | awk '{print $1}')
kubectl wait --timeout=5m --for=condition=ready pod/$POD

echo "> peer and blockchain-adapter pods are ready"