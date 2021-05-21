#!/bin/bash
# abort processing on the first error
set -e -o pipefail

# load config
. setup.cfg

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

echo "> creating dirs..."
kubectl -n $CFG_KUBENS exec fabric-tools -- mkdir -p /mnt/data/WEBAPP/nginx/certs

echo "> deploying certbot pod and svc..."
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/webapp-certbot-svc.yaml
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/webapp-certbot-pod.yaml

echo "> waiting for webapp pod to be ready"
POD=$(kubectl -n $CFG_KUBENS get pods | grep ^nginx-certbot- | awk '{print $1}')
kubectl wait --timeout=5m --for=condition=ready pod/$POD

sleep 2

echo "> issuing ssl certificates for ${CFG_HOSTNAME}.${CFG_DOMAIN}..."
kubectl -n $CFG_KUBENS exec $POD -- certbot certonly --standalone  -n --agree-tos --email ${CFG_NGINX_CERT_MAIL} -d ${CFG_HOSTNAME}.${CFG_DOMAIN}

while [ -z "$(kubectl -n $CFG_KUBENS exec $POD -- ls -A /etc/letsencrypt/live/${CFG_HOSTNAME}.${CFG_DOMAIN} 2> /dev/null))" ] 
do       
  sleep 2
done

sleep 2

kubectl -n $CFG_KUBENS exec $POD -- cp /etc/letsencrypt/live/${CFG_HOSTNAME}.${CFG_DOMAIN}/fullchain.pem /home/certs/cert.crt
kubectl -n $CFG_KUBENS exec $POD -- cp /etc/letsencrypt/live/${CFG_HOSTNAME}.${CFG_DOMAIN}/privkey.pem /home/certs/cert.key

sleep 1

echo "> stoping certbot pod and svc..."
kubectl delete -f $CFG_CONFIG_PATH/kubernetes/webapp-certbot-svc.yaml
kubectl delete -f $CFG_CONFIG_PATH/kubernetes/webapp-certbot-pod.yaml

echo "> all done." 
