#!/bin/bash

export CORE_PEER_LOCALMSPID=${ORG}MSP
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_TLS_CLIENTAUTHREQUIRED=true

export CORE_PEER_ADDRESS=${PEER_NAME}.${HOSTNAME}.${DOMAIN}:${PEER_PORT}

export CORE_PEER_TLS_CLIENTKEY_FILE=${ADMIN_BASE}/msp/keystore/priv_sk
export CORE_PEER_MSPCONFIGPATH=${ADMIN_BASE}/msp
export CORE_PEER_TLS_CLIENTCERT_FILE=${ADMIN_BASE}/msp/signcerts/Admin@${HOSTNAME}.${DOMAIN}-cert.pem
export CORE_PEER_TLS_ROOTCERT_FILE=${PEER_BASE}/tls/ca.crt

export ORDERER_CA=/opt/certs/tlsca.orderer.hldid.org-cert.pem
export ORDERER_MTLS_KEY=/opt/certs/mtls.orderer.hldid.org-key.key
export ORDERER_MTLS_CRT=/opt/certs/mtls.orderer.hldid.org-cert.crt

"$@" --tls --cafile $ORDERER_CA  --clientauth --certfile $ORDERER_MTLS_CRT --keyfile $ORDERER_MTLS_KEY

exit $?