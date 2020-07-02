#!/bin/bash
. setup.cfg

if [ $# -ne 2 ]; then 
    echo "> usage: $0 <GSMA_CSR_USER> <GSMA_CSR_PASSWORD>"
    exit 1
fi

CSR_USER=$1
CSR_PASS=$2

FILENAME_PK="$CFG_CONFIG_PATH_CA/priv_key.pem"
FILENAME_CSR="$CFG_CONFIG_PATH_CA/ca.csr"
FILENAME_CERT="$CFG_CONFIG_PATH_CA/ca-cert.pem"

SUBJECT="/C=${CFG_CA_C}/ST=${CFG_CA_ST}/L=${CFG_CA_L}/O=${CFG_CA_O}/OU=${CFG_CA_OU}/CN=ca.${CFG_HOSTNAME}.${CFG_DOMAIN}/2.5.4.41=${CFG_ORG}MSP"

CA_CHAIN_INPUT=template/cert/ca-chain.pem

# make sure the output path exist
mkdir -p $CFG_CONFIG_PATH_CA

echo "> generating private key $FILENAME_PK"
openssl ecparam -name prime256v1 -genkey -noout -out $FILENAME_PK || exit 1

echo "> generating CSR $FILENAME_CSR with subject '$SUBJECT'"
openssl req -new -sha256 -key $FILENAME_PK -out $FILENAME_CSR -subj "$SUBJECT" || exit 1

echo "> signing certificate at $CERT_SIGNER_URL, using user $CSR_USER"
curl -s -k -X POST $CERT_SIGNER_URL -F"user=${CSR_USER}" -F"password=${CSR_PASS}" -F"pkcs10file=@$FILENAME_CSR" -F"resulttype=1" --output $FILENAME_CERT || exit 1
cat $FILENAME_CERT

if grep -q "Wrong username" "$FILENAME_CERT"; then
    echo "> failed to login, wrong user/password?!"
    exit 1;
fi

echo "> verifying if signed cert is readable"
openssl x509 -in $FILENAME_CERT -text 
if [ "$?" -ne 0 ]; then
    echo "ERROR> Unable to receive Certificate. Please contact the Administrator"
    rm $CFG_CONFIG_PATH_CA/ca-cert.pem
    rm $CFG_CONFIG_PATH_CA/priv_key.pem
    rm $CFG_CONFIG_PATH_CA/ca.csr
    exit 1
fi

echo "> creating certificate chain based on template $CA_CHAIN_INPUT"
cp $CA_CHAIN_INPUT $CFG_CONFIG_PATH_CA/
cat $CFG_CONFIG_PATH_CA/ca-cert.pem >> $CFG_CONFIG_PATH_CA/ca-chain.pem

echo "> done. make sure to backup your certificats in $CFG_CONFIG_PATH_CA/"