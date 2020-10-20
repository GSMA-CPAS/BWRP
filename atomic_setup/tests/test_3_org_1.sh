#!/bin/sh
set -e -o errexit
export no_proxy="localhost,$no_proxy"

. ./test_setup.cfg

ORG_1_NAME_LOWERCASE=$(echo "$ORG_NAME_1" | tr '[:upper:]' '[:lower:]')
ORG_1_NAME_UPPERCASE=$(echo "$ORG_NAME_1" | tr '[:lower:]' '[:upper:]')
ORG_2_NAME_LOWERCASE=$(echo "$ORG_NAME_2" | tr '[:upper:]' '[:lower:]')
ORG_2_NAME_UPPERCASE=$(echo "$ORG_NAME_2" | tr '[:lower:]' '[:upper:]')

[ ! -z "$BSA_DEBUG" ] && set -e -x

# SOME OPTIONS
SIGNER_ONE="$ORG_1_NAME_LOWERCASE@CST"
SIGNER_TWO="$ORG_2_NAME_LOWERCASE@CST"

# generate crypto material:
DIR=$(mktemp -d)
KEY=$DIR/KEY
CRT=$DIR/CRT
PUB_ONE=$DIR/PUB_ONE
PUB_TWO=$DIR/PUB_TWO
DOC=$DIR/DOC
# make sure to remove temp files on exit
trap "{ rm -fr $DIR; }" EXIT

DOCUMENT64=$1
DOCUMENT=$2

function request {
    RET=$(curl -s -S -X $1 -H "Content-Type: application/json" -d "$2" "$3")
    echo $RET
    echo $RET | grep -i "error" > /dev/null && echo $RET > /dev/stderr && exit 1 || : 
}  

echo "###################################################"
echo "> storing document on both parties by calling the function on $ORG_1_NAME_UPPERCASE with the partner id $ORG_2_NAME_UPPERCASE"
RES=$(request "POST" '{ "toMSP" : "'$ORG_2_NAME_UPPERCASE'MSP", "data" : "'$DOCUMENT64'" }'  $CFG_ORG_1_BLOCKCHAIN_ADAPTER_URL/private-documents)
echo $RES
DOCUMENT_ID=$(echo "$RES" | jq -r .documentID)

echo "###################################################"
echo "> $ORG_1_NAME_LOWERCASE signs contract"
# generate key and crt
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:secp384r1 -nodes -keyout $KEY -out $CRT -subj "/CN=${SIGNER_ONE}/C=DE/ST=NRW/L=Bielefeld/O=ORG/OU=ORGOU" -addext keyUsage=digitalSignature
# create pem formatted with \n
CERT=$(cat $CRT | awk 1 ORS='\\n')
# extract public key
openssl x509 -pubkey -in $CRT > $PUB_ONE
# do the signing
SIGNATURE=$(echo -ne $DOCUMENT | openssl dgst -sha256 -sign $KEY | openssl base64 | tr -d '\n')
# call blockchain adapter
request "PUT" '{"algorithm": "secp384r1", "certificate" : "'"${CERT}"'", "signature" : "'"${SIGNATURE}"'" }'  $CFG_ORG_1_BLOCKCHAIN_ADAPTER_URL/signatures/$DOCUMENT_ID

echo "send to org_2 to add next as args on the test_4_org_2.sh"
echo "$DOCUMENT64 $DOCUMENT $DOCUMENT_ID"

