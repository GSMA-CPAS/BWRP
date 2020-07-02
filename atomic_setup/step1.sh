#!/bin/bash
# abort processing on the first error
set -e -o pipefail

# load config
. setup.cfg

# set up templates
./replace_variables.sh setup.cfg ./$CFG_CONFIG_PATH/

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS
kubectl create -f $CFG_CONFIG_PATH/kubernetes/namespace.yaml || echo "namespace exists, not deploying"

echo "> deploying persistant volume"
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/data-storage-pv.yaml

echo "> deploying fabric-tools container for initial setup"
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/fabric-tools.yaml
echo "> waiting for pod ready condition"
kubectl wait --timeout=5m --for=condition=ready pod/fabric-tools

echo "> deploying fabric-ca-tools container for initial ca setup"
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/fabric-ca-tools.yaml
echo "> waiting for pod ready condition"
kubectl wait --timeout=5m --for=condition=ready pod/fabric-ca-tools


echo "> copy CA data to PVC"
kubectl cp $CFG_CONFIG_PATH/ca fabric-ca-tools:/mnt/data/CA
kubectl cp $CFG_CONFIG_PATH/config/fabric-ca-server-config.yaml fabric-tools:/mnt/data/CA/
# show data
kubectl exec fabric-ca-tools -- ls -al /mnt/data/CA

echo "> deploying ca"
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/ca-deploy.yaml
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/ca-svc.yaml

echo "> waiting for ca pod to be ready"
POD=$(kubectl get pods | grep ^ca- | awk '{print $1}')
kubectl wait --timeout=5m --for=condition=ready pod/$POD

exit;

echo "Please make sure pod is running."
echo "kubectl get pods --selector=io.kompose.service=ca-$MYHOST -o=wide -n $KUBENS"
echo
echo "Get the 'ca' IP address and add it to your /etc/hosts as (using below cmd, labeld as 'CLUSTER-IP')"
echo "kubectl get svc --selector=io.kompose.service=ca-$MYHOST -o=wide -n $KUBENS"
echo "XXX.XXX.XXX.XXX	ca-$MYHOST.local"
echo

echo
echo "Continue to execute './step2.sh' for further instructions"
echo
echo
