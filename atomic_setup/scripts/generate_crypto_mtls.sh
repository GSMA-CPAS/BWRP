#!/bin/bash
# abort processing on the first error
set -e -o pipefail

# load config
. setup.cfg

CA_URL="ca-$CFG_MYHOST.$CFG_KUBENS:$CFG_CA_PORT"
CA_ROOT_DIR="/mnt/data/CA"
CA_CLIENT_DIR="/mnt/data/ca-client"
CA_CLIENT_OPTS="--caname ca.$CFG_HOSTNAME.$CFG_DOMAIN -H $CA_CLIENT_DIR --tls.certfiles $CA_ROOT_DIR/tls-cert.pem"
CFG_USER_BASE="$CFG_PEER_DIR/users/$CFG_CA_PEER_TLS_USERNAME@$CFG_HOSTNAME.$CFG_DOMAIN"

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

echo "> deploying helper script"
kubectl cp scripts/process_pem.sh fabric-ca-tools:/opt

echo "> enrolling admin user"
kubectl exec fabric-ca-tools -- fabric-ca-client enroll -u https://admin:$CFG_CA_ADMINPW@$CA_URL $CA_CLIENT_OPTS
echo "> registering mtls user $CFG_CA_PEER_TLS_USERNAME"
kubectl exec fabric-ca-tools -- fabric-ca-client register --id.name $CFG_CA_PEER_TLS_USERNAME --id.secret $CFG_CA_PEER_TLS_USERPW --id.type user $CA_CLIENT_OPTS | sed 's|Password: \(.*\)|Password: *** hidden ***\r|'
echo "> enrolling mtls user $CFG_CA_PEER_TLS_USERNAME"
kubectl exec fabric-ca-tools -- fabric-ca-client enroll -u https://$CFG_CA_PEER_TLS_USERNAME:$CFG_CA_PEER_TLS_USERPW@$CA_URL -M $CFG_USER_BASE/msp $CA_CLIENT_OPTS

echo "> MSP: splitting user certs"
kubectl exec fabric-ca-tools -- /opt/process_pem.sh $CFG_USER_BASE/msp/cacerts
kubectl exec fabric-ca-tools -- /opt/process_pem.sh $CFG_USER_BASE/msp/intermediatecerts

echo "> MSP: moving user certs and keys"
kubectl exec fabric-ca-tools -- sh -c "mv $CFG_USER_BASE/msp/keystore/* $CFG_USER_BASE/msp/keystore/priv_sk"
kubectl exec fabric-ca-tools -- sh -c "mv $CFG_USER_BASE/msp/signcerts/* $CFG_USER_BASE/msp/signcerts/$CFG_CA_PEER_TLS_USERNAME@$CFG_HOSTNAME.$CFG_DOMAIN-cert.pem"

echo "> MSP: copy user config yaml"
kubectl cp $CFG_CONFIG_PATH/config/msp-config.yaml fabric-tools:$CFG_USER_BASE/msp/config.yaml

echo "> enrolling user tls"
kubectl exec fabric-ca-tools -- fabric-ca-client enroll -u https://$CFG_CA_PEER_TLS_USERNAME:$CFG_CA_PEER_TLS_USERPW@$CA_URL --enrollment.profile tls -M $CFG_USER_BASE/tls $CA_CLIENT_OPTS

echo "> TLS: splitting user certs"
kubectl exec fabric-ca-tools -- /opt/process_pem.sh $CFG_USER_BASE/tls/tlscacerts
kubectl exec fabric-ca-tools -- /opt/process_pem.sh $CFG_USER_BASE/tls/tlsintermediatecerts

echo "> TLS: moving user certs and keys"
kubectl exec fabric-ca-tools -- cp $CFG_USER_BASE/tls/tlsintermediatecerts/ca.$CFG_HOSTNAME.$CFG_DOMAIN-cert.pem $CFG_USER_BASE/tls/ca.crt
kubectl exec fabric-ca-tools -- sh -c "mv $CFG_USER_BASE/tls/signcerts/* $CFG_USER_BASE/tls/server.crt"
kubectl exec fabric-ca-tools -- sh -c "mv $CFG_USER_BASE/tls/keystore/* $CFG_USER_BASE/tls/server.key"

echo "> TLS: pushing user cert to MSP"
kubectl exec fabric-ca-tools -- mkdir -p $CFG_USER_BASE/msp/tlscacerts
kubectl exec fabric-ca-tools -- cp $CFG_USER_BASE/tls/ca.crt $CFG_USER_BASE/msp/tlscacerts/tlsca.$CFG_HOSTNAME.$CFG_DOMAIN-cert.pem

echo "> Copy user certs from PVC to deployment/pvc/ca/users/"
kubectl cp fabric-ca-tools:/mnt/data/peer/users/$CFG_CA_PEER_TLS_USERNAME@$CFG_HOSTNAME.$CFG_DOMAIN deployment/pvc/ca/users/$CFG_CA_PEER_TLS_USERNAME@$CFG_HOSTNAME.$CFG_DOMAIN
