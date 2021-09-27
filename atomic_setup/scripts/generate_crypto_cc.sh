#!/bin/bash
# abort processing on the first error
set -e -o pipefail

# load config
. setup.cfg

CA_URL="ca-$CFG_MYHOST.$CFG_KUBENS:$CFG_CA_PORT"
CA_ROOT_DIR="/mnt/data/CA"
CA_CLIENT_DIR="/mnt/data/ca-client"
CA_CLIENT_OPTS="--caname ca.$CFG_HOSTNAME.$CFG_DOMAIN -H $CA_CLIENT_DIR --tls.certfiles $CA_ROOT_DIR/tls-cert.pem"

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

echo "> deploying helper script"
kubectl cp scripts/process_pem.sh fabric-ca-tools:/opt

echo "> enrolling admin user"
kubectl exec fabric-ca-tools -- fabric-ca-client enroll -u https://admin:$CFG_CA_ADMINPW@$CA_URL $CA_CLIENT_OPTS
echo "> register $CFG_CC_NAME user"
kubectl exec fabric-ca-tools -- fabric-ca-client register --id.name $CFG_CC_NAME --id.secret $CFG_CA_CC_TLS_USERPW --id.type peer $CA_CLIENT_OPTS | sed 's|Password: \(.*\)|Password: *** hidden ***\r|' || echo "user already registered"

echo "> enrolling $CFG_CC_NAME tls"
kubectl exec fabric-ca-tools -- fabric-ca-client enroll -u https://$CFG_CC_NAME:$CFG_CA_CC_TLS_USERPW@$CA_URL --enrollment.profile tls -M $CFG_PEER_BASE/tls-cc --csr.hosts $CFG_CC_NAME $CA_CLIENT_OPTS

echo "> TLS: splitting $CFG_CC_NAME certs"
kubectl exec fabric-ca-tools -- /opt/process_pem.sh $CFG_PEER_BASE/tls-cc/tlscacerts
kubectl exec fabric-ca-tools -- /opt/process_pem.sh $CFG_PEER_BASE/tls-cc/tlsintermediatecerts

echo "> TLS: moving $CFG_CC_NAME certs and keys"
kubectl exec fabric-ca-tools -- cp $CFG_PEER_BASE/tls-cc/tlsintermediatecerts/ca.$CFG_HOSTNAME.$CFG_DOMAIN-cert.pem $CFG_PEER_BASE/tls-cc/ca.crt
kubectl exec fabric-ca-tools -- sh -c "mv $CFG_PEER_BASE/tls-cc/signcerts/* $CFG_PEER_BASE/tls-cc/server.crt"
kubectl exec fabric-ca-tools -- sh -c "mv $CFG_PEER_BASE/tls-cc/keystore/* $CFG_PEER_BASE/tls-cc/server.key"
kubectl exec fabric-ca-tools -- sh -c "chmod a+rx $CFG_PEER_BASE/tls-cc/keystore/* $CFG_PEER_BASE/tls-cc"
kubectl exec fabric-ca-tools -- sh -c "chmod a+r $CFG_PEER_BASE/tls-cc/keystore/* $CFG_PEER_BASE/tls-cc/*"
