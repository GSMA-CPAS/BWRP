#!/bin/bash
# abort processing on the first error
set -e -o pipefail

# load config
. setup.cfg

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

echo "> deploying certbot pod and svc..."
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/webapp-certbot-svc.yaml
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/webapp-certbot-pod.yaml

echo "> waiting for webapp pod to be ready"
POD=$(kubectl -n $CFG_KUBENS get pods | grep ^nginx-certbot- | awk '{print $1}')
kubectl wait --timeout=5m --for=condition=ready pod/$POD

sleep 2

echo "> renew ssl certificates for ${CFG_HOSTNAME}.${CFG_DOMAIN}..."
kubectl -n $CFG_KUBENS exec $POD -- certbot renew

sleep 30

kubectl -n $CFG_KUBENS exec $POD -- cp /etc/letsencrypt/live/${CFG_HOSTNAME}.${CFG_DOMAIN}/fullchain.pem /home/certs/cert.crt
kubectl -n $CFG_KUBENS exec $POD -- cp /etc/letsencrypt/live/${CFG_HOSTNAME}.${CFG_DOMAIN}/privkey.pem /home/certs/cert.key

sleep 2

echo "> stoping certbot pod and svc..."
kubectl delete -f $CFG_CONFIG_PATH/kubernetes/webapp-certbot-svc.yaml
kubectl delete -f $CFG_CONFIG_PATH/kubernetes/webapp-certbot-pod.yaml

echo "> all done." 
