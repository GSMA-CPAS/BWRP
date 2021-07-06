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
#echo "> register $CFG_PEER_NAME user"
#kubectl exec fabric-ca-tools -- fabric-ca-client register --id.name $CFG_PEER_NAME --id.secret $CFG_CA_PEERPW --id.type peer $CA_CLIENT_OPTS | sed 's|Password: \(.*\)|Password: *** hidden ***\r|'
echo "> enrolling $CFG_PEER_NAME user"
kubectl exec fabric-ca-tools -- fabric-ca-client enroll -u https://$CFG_PEER_NAME:$CFG_CA_PEERPW@$CA_URL -M $CFG_PEER_BASE/msp --csr.hosts $CFG_PEER_NAME.$CFG_HOSTNAME.$CFG_DOMAIN $CA_CLIENT_OPTS

echo "> MSP: splitting $CFG_PEER_NAME certs"
kubectl exec fabric-ca-tools -- /opt/process_pem.sh $CFG_PEER_BASE/msp/cacerts
kubectl exec fabric-ca-tools -- /opt/process_pem.sh $CFG_PEER_BASE/msp/intermediatecerts

echo "> MSP: moving $CFG_PEER_NAME certs and keys"
kubectl exec fabric-ca-tools -- sh -c "mv $CFG_PEER_BASE/msp/keystore/* $CFG_PEER_BASE/msp/keystore/priv_sk"
kubectl exec fabric-ca-tools -- sh -c "mv $CFG_PEER_BASE/msp/signcerts/* $CFG_PEER_BASE/msp/signcerts/$CFG_PEER_NAME.$CFG_HOSTNAME.$CFG_DOMAIN-cert.pem"

echo "> MSP: copy $CFG_PEER_NAME config yaml"
kubectl cp $CFG_CONFIG_PATH/config/msp-config.yaml fabric-tools:$CFG_PEER_BASE/msp/config.yaml

echo "> enrolling $CFG_PEER_NAME tls"
kubectl exec fabric-ca-tools -- fabric-ca-client enroll -u https://$CFG_PEER_NAME:$CFG_CA_PEERPW@$CA_URL --enrollment.profile tls -M $CFG_PEER_BASE/tls --csr.hosts $CFG_PEER_NAME.$CFG_HOSTNAME.$CFG_DOMAIN $CA_CLIENT_OPTS

echo "> TLS: splitting $CFG_PEER_NAME certs"
kubectl exec fabric-ca-tools -- /opt/process_pem.sh $CFG_PEER_BASE/tls/tlscacerts
kubectl exec fabric-ca-tools -- /opt/process_pem.sh $CFG_PEER_BASE/tls/tlsintermediatecerts

echo "> TLS: moving $CFG_PEER_NAME certs and keys"
kubectl exec fabric-ca-tools -- cp $CFG_PEER_BASE/tls/tlsintermediatecerts/ca.$CFG_HOSTNAME.$CFG_DOMAIN-cert.pem $CFG_PEER_BASE/tls/ca.crt
kubectl exec fabric-ca-tools -- sh -c "mv $CFG_PEER_BASE/tls/signcerts/* $CFG_PEER_BASE/tls/server.crt"
kubectl exec fabric-ca-tools -- sh -c "mv $CFG_PEER_BASE/tls/keystore/* $CFG_PEER_BASE/tls/server.key"

echo "> TLS: pushing $CFG_PEER_NAME cert to MSP"
kubectl exec fabric-ca-tools -- mkdir -p $CFG_PEER_BASE/msp/tlscacerts
kubectl exec fabric-ca-tools -- cp $CFG_PEER_BASE/tls/ca.crt $CFG_PEER_BASE/msp/tlscacerts/tlsca.$CFG_HOSTNAME.$CFG_DOMAIN-cert.pem

echo "> setting up configtxgen"
kubectl exec fabric-tools -- mkdir -p $CFG_PEER_DIR
kubectl cp $CFG_CONFIG_PATH/config/configtx.yaml fabric-ca-tools:/$CFG_PEER_DIR
echo "> running configtxgen"
kubectl exec fabric-tools -- sh -c "echo \".values += {\\\"AnchorPeers\\\":{\\\"mod_policy\\\":\\\"Admins\\\",\\\"value\\\":{\\\"anchor_peers\\\":[{\\\"host\\\":\\\"$CFG_PEER_NAME.$CFG_HOSTNAME.$CFG_DOMAIN\\\",\\\"port\\\":\\\"$CFG_PEER_PORT\\\"}]},\\\"version\\\":\\\"0\\\"}}\" > $CFG_PEER_DIR/.$CFG_ORG.jq"
kubectl exec fabric-tools -- sh -c "FABRIC_CFG_PATH=$CFG_PEER_DIR; configtxgen -printOrg ${CFG_ORG}MSP | jq -f $CFG_PEER_DIR/.$CFG_ORG.jq > $CFG_PEER_DIR/$CFG_ORG.json"

#echo "> registering peer admin user $CFG_PEER_ADMIN"
#kubectl exec fabric-ca-tools -- fabric-ca-client register --id.name $CFG_PEER_ADMIN --id.secret $CFG_CA_PEERADMINPW --id.type admin $CA_CLIENT_OPTS | sed 's|Password: \(.*\)|Password: *** hidden ***\r|'
echo "> enrolling peer admin user $CFG_PEER_ADMIN"
kubectl exec fabric-ca-tools -- fabric-ca-client enroll -u https://$CFG_PEER_ADMIN:$CFG_CA_PEERADMINPW@ca-$CFG_MYHOST.$CFG_KUBENS:$CFG_CA_PORT -M $CFG_ADMIN_BASE/msp $CA_CLIENT_OPTS

echo "> MSP: splitting admin certs"
kubectl exec fabric-ca-tools -- /opt/process_pem.sh $CFG_ADMIN_BASE/msp/cacerts
kubectl exec fabric-ca-tools -- /opt/process_pem.sh $CFG_ADMIN_BASE/msp/intermediatecerts

echo "> MSP: moving admin certs and keys"
kubectl exec fabric-ca-tools -- sh -c "mv $CFG_ADMIN_BASE/msp/keystore/* $CFG_ADMIN_BASE/msp/keystore/priv_sk"
kubectl exec fabric-ca-tools -- sh -c "mv $CFG_ADMIN_BASE/msp/signcerts/* $CFG_ADMIN_BASE/msp/signcerts/Admin@$CFG_HOSTNAME.$CFG_DOMAIN-cert.pem"

echo "> MSP: copy admin config yaml"
kubectl cp $CFG_CONFIG_PATH/config/msp-config.yaml fabric-tools:$CFG_ADMIN_BASE/msp/config.yaml

echo "> enrolling admin tls"
kubectl exec fabric-ca-tools -- fabric-ca-client enroll -u https://$CFG_PEER_ADMIN:$CFG_CA_PEERADMINPW@$CA_URL --enrollment.profile tls -M $CFG_ADMIN_BASE/tls $CA_CLIENT_OPTS

echo "> TLS: splitting admin certs"
kubectl exec fabric-ca-tools -- /opt/process_pem.sh $CFG_ADMIN_BASE/tls/tlscacerts
kubectl exec fabric-ca-tools -- /opt/process_pem.sh $CFG_ADMIN_BASE/tls/tlsintermediatecerts

echo "> TLS: moving admin certs and keys"
kubectl exec fabric-ca-tools -- cp $CFG_ADMIN_BASE/tls/tlsintermediatecerts/ca.$CFG_HOSTNAME.$CFG_DOMAIN-cert.pem $CFG_ADMIN_BASE/tls/ca.crt
kubectl exec fabric-ca-tools -- sh -c "mv $CFG_ADMIN_BASE/tls/signcerts/* $CFG_ADMIN_BASE/tls/server.crt"
kubectl exec fabric-ca-tools -- sh -c "mv $CFG_ADMIN_BASE/tls/keystore/* $CFG_ADMIN_BASE/tls/server.key"

echo "> TLS: pushing admin cert to MSP"
kubectl exec fabric-ca-tools -- mkdir -p $CFG_ADMIN_BASE/msp/tlscacerts
kubectl exec fabric-ca-tools -- cp $CFG_ADMIN_BASE/tls/ca.crt $CFG_ADMIN_BASE/msp/tlscacerts/tlsca.$CFG_HOSTNAME.$CFG_DOMAIN-cert.pem

echo "> downloading CA config backup from pod..."
mkdir -p $CFG_CONFIG_PATH_PVC/ca
kubectl cp fabric-ca-tools:$CFG_PEER_DIR $CFG_CONFIG_PATH_PVC/ca

echo "> Please send $CFG_CONFIG_PATH_PVC/ca/$CFG_ORG.json to DLT Administrator"
echo "> Note: It is a good idea to backup $CFG_CONFIG_PATH now!"
