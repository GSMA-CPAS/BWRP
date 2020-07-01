#!/bin/bash
. setup.sh

# set up templates
./replace_variables.sh

echo "> setting namespace"
kubectl config set-context --current --namespace=$KUBENS
kubectl create -f generated_config/kubernetes/namespace.yaml || echo "namespace exists, not deploying"

echo "> deploying persistant volume"
kubectl apply -f generated_config/kubernetes/data-storage-pv.yaml

echo "> deploying fabrictools container for initial setup"
kubectl apply -f generated_config/kubernetes/fabric-tools.yaml
echo "> waiting for pod ready condition"
kubectl wait --timeout=5m --for=condition=ready pod/fabric-tools

echo "> copy CA data to PVC"
kubectl cp $CONFIG_PATH_CA fabric-tools:/mnt/data/CA
kubectl cp generated_config/config/fabric-ca-server-config.yaml fabric-tools:/mnt/data/CA/
# show data
kubectl exec fabric-tools -- ls -al /mnt/data/CA

echo "> deploying ca"
kubectl apply -f generated_config/kubernetes/ca-deploy.yaml
kubectl apply -f generated_config/kubernetes/ca-svc.yaml

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
