#!/bin/bash
# abort processing on the first error
set -e -o pipefail

# load config
. setup.cfg

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

echo "> creating dirs..."
kubectl -n $CFG_KUBENS exec fabric-tools -- mkdir -p /mnt/data/WEBAPP/nginx/certs
kubectl -n $CFG_KUBENS exec fabric-tools -- mkdir -p /mnt/data/WEBAPP/nginx/conf.d
kubectl -n $CFG_KUBENS exec fabric-tools -- mkdir -p /mnt/data/WEBAPP/nginx/sites-available

echo "> uploading nginx files..."
kubectl -n $CFG_KUBENS cp $CFG_CONFIG_PATH/nginx/conf.d/main_error_404.html fabric-tools:/mnt/data/WEBAPP/nginx/conf.d/
kubectl -n $CFG_KUBENS cp $CFG_CONFIG_PATH/nginx/conf.d/main_error_50x.html fabric-tools:/mnt/data/WEBAPP/nginx/conf.d/
kubectl -n $CFG_KUBENS cp $CFG_CONFIG_PATH/nginx/conf.d/nomad_nginx.conf fabric-tools:/mnt/data/WEBAPP/nginx/conf.d/
kubectl -n $CFG_KUBENS cp $CFG_CONFIG_PATH/nginx/conf.d/nomad_nginx.conf fabric-tools:/mnt/data/WEBAPP/nginx/sites-available/

echo "> deploying nginx svc and pod..."
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/webapp-nginx-svc.yaml
kubectl apply -f $CFG_CONFIG_PATH/kubernetes/webapp-nginx-pod.yaml

echo "> waiting for nginx cert bot to start"
POD=$(kubectl -n $CFG_KUBENS get pods | grep ^nginx-webapp- | awk '{print $1}')
kubectl wait --timeout=5m --for=condition=ready pod/$POD

echo "> all done." 
