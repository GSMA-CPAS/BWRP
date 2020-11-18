#!/bin/bash
# abort processing on the first error
set -e -o pipefail

# load config
. setup.cfg

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

echo "> creating dirs..."
kubectl -n $CFG_KUBENS exec fabric-tools -- mkdir -p /mnt/data/WEBAPP/config
kubectl -n $CFG_KUBENS exec fabric-tools -- mkdir -p /mnt/data/WEBAPP/DB
kubectl -n $CFG_KUBENS exec fabric-tools -- mkdir -p /mnt/data/WEBAPP/certs

kubectl -n $CFG_KUBENS exec fabric-tools -- mkdir -p /mnt/data/WEBAPP/nginx/certs
kubectl -n $CFG_KUBENS exec fabric-tools -- mkdir -p /mnt/data/WEBAPP/nginx/conf.d
kubectl -n $CFG_KUBENS exec fabric-tools -- mkdir -p /mnt/data/WEBAPP/nginx/sites-available

echo "> uploading webapp files..."
kubectl -n $CFG_KUBENS cp $CFG_CONFIG_PATH/webapp/production.json fabric-tools:/mnt/data/WEBAPP/config/
kubectl -n $CFG_KUBENS cp $CFG_CONFIG_PATH/webapp/default.json fabric-tools:/mnt/data/WEBAPP/config/
kubectl -n $CFG_KUBENS cp $CFG_CONFIG_PATH/webapp/custom-environment-variables.json fabric-tools:/mnt/data/WEBAPP/config/

echo "> uploading nginx files..."
kubectl -n $CFG_KUBENS cp $CFG_CONFIG_PATH/nginx/conf.d/main_error_404.html fabric-tools:/mnt/data/WEBAPP/nginx/conf.d/
kubectl -n $CFG_KUBENS cp $CFG_CONFIG_PATH/nginx/conf.d/main_error_50x.html fabric-tools:/mnt/data/WEBAPP/nginx/conf.d/
kubectl -n $CFG_KUBENS cp $CFG_CONFIG_PATH/nginx/conf.d/nomad_nginx.conf fabric-tools:/mnt/data/WEBAPP/nginx/conf.d/
kubectl -n $CFG_KUBENS cp $CFG_CONFIG_PATH/nginx/conf.d/nomad_nginx.conf fabric-tools:/mnt/data/WEBAPP/nginx/sites-available/

echo "> deploying frontend pod and svc..."
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/webapp-svc.yaml
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/webapp-pod.yaml

echo "> waiting for webapp pod to be ready"
POD=$(kubectl -n $CFG_KUBENS get pods | grep ^webapp- | awk '{print $1}')
kubectl wait --timeout=5m --for=condition=ready pod/$POD

echo "> deploying nginx svc..."
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/webapp-nginx-svc.yaml
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/webapp-nginx-cert.yaml

echo "> waiting for nginx cert bot to start"
POD=$(kubectl -n $CFG_KUBENS get pods | grep ^nginx-webapp- | awk '{print $1}')
kubectl wait --timeout=5m --for=condition=ready pod/$POD

sleep 5

echo "> issuing ssl certificates for ${CFG_HOSTNAME}.${CFG_DOMAIN}..."
kubectl -n $CFG_KUBENS exec $POD -- certbot certonly --standalone  -n --agree-tos --email ${CFG_NGINX_CERT_MAIL} -d ${CFG_HOSTNAME}.${CFG_DOMAIN}

while [ -z "$(kubectl -n $CFG_KUBENS exec $POD -- ls -A /etc/letsencrypt/live/${CFG_HOSTNAME}.${CFG_DOMAIN})" ] 
do       
  sleep 2
done

sleep 2

kubectl -n $CFG_KUBENS exec $POD -- cp /etc/letsencrypt/live/${CFG_HOSTNAME}.${CFG_DOMAIN}/fullchain.pem /home/certs/cert.crt
kubectl -n $CFG_KUBENS exec $POD -- cp /etc/letsencrypt/live/${CFG_HOSTNAME}.${CFG_DOMAIN}/privkey.pem /home/certs/cert.key

sleep 2

echo "> deploying nginx pod..."
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/webapp-nginx-pod.yaml

echo "> waiting for nginx pod to be ready"
POD=$(kubectl -n $CFG_KUBENS get pods | grep ^nginx-webapp- | awk '{print $1}')
kubectl wait --timeout=5m --for=condition=ready pod/$POD

echo "> all done." 
