#!/bin/bash
# abort processing on the first error
set -e -o pipefail

. setup.cfg

kubectl -n $CFG_KUBENS cp fabric-ca-tools:/mnt/data/CA/tls-cert.pem ./tls-cert.pem

CA_TLS=$(cat ./tls-cert.pem |  awk 1 ORS='\\n' | sed -e 's/[\/&]/\\&/g')
sed -i "s|from_ca_tls|$CA_TLS|g" $CFG_CONFIG_PATH/config/webapp/production.json

rm ./tls-cert.pem

