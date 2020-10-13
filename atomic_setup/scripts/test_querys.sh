#!/bin/bash
set -e -o errexit
export no_proxy="localhost,$no_proxy"

# allow env override, fill endpoints of organisations blockchain-adapter
[ -z "$BSA_ORG1" ] && BSA_ORG1="localhost:8081"
[ ! -z "$BSA_DEBUG" ] && set -e -x

# SOME OPTIONS
SIGNER_ORG1="user@org1"

# create a unique document if not passed via command line
[ -z "$DOCUMENT" ] && DOCUMENT=$(date +%s) 

DOCUMENT64=$(echo $DOCUMENT | openssl base64 | tr -d '\n')
DOCUMENTSHA256=$(echo -n $DOCUMENT64 | openssl dgst -sha256 -r | cut -d " " -f1)
echo "> calculated hash $DOCUMENTSHA256 for document"

# generate crypto material:
DIR=$(mktemp -d)
KEY=$DIR/KEY
CRT=$DIR/CRT
PUB_ORG1=$DIR/PUB_ORG1
PUB_ORG2=$DIR/PUB_ORG2
DOC=$DIR/DOC
# make sure to remove temp files on exit
trap "{ rm -fr $DIR; }" EXIT

function request {
    RET=$(curl -s -S -X $1 -H "Content-Type: application/json" -d "$2" "$3")
    echo $RET
    echo $RET | grep -i "error" > /dev/null && echo $RET > /dev/stderr && exit 1 || : 
}  

# rest uri of org2 has to be setted

echo "###################################################"
echo "> setting rest uri on org1"
request "PUT" '{"restURI": "http://offchain-db-adapter-org1:3333"}' http://$BSA_ORG1/config/offchain-db-adapter

echo "###################################################"
echo "> storing document on both parties by calling the function on ORG1 with the partner id ORG2"
RES=$(request "POST" '{ "toMSP" : "ORG2", "data" : "'$DOCUMENT64'" }'  http://$BSA_ORG1/private-documents)
echo $RES
DOCUMENT_ID=$(echo "$RES" | jq -r .documentID)

echo "###################################################"
echo "> org1 signs contract"
# generate key and crt
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:secp384r1 -nodes -keyout $KEY -out $CRT -subj "/CN=${SIGNER_ORG1}/C=DE/ST=NRW/L=Bielefeld/O=ORG/OU=ORGOU" -addext keyUsage=digitalSignature
# create pem formatted with \n
CERT=$(cat $CRT | awk 1 ORS='\\n')
# extract public key
openssl x509 -pubkey -in $CRT > $PUB_ORG1
# do the signing
SIGNATURE=$(echo -ne $DOCUMENT | openssl dgst -sha256 -sign $KEY | openssl base64 | tr -d '\n')
# call blockchain adapter
request "PUT" '{"algorithm": "secp384r1", "certificate" : "'"${CERT}"'", "signature" : "'$SIGNATURE'" }'  http://$BSA_ORG1/signatures/$DOCUMENT_ID

echo "###################################################"
echo "> fetching contract from org1"
RES=$(request "GET" "" http://$BSA_ORG1/private-documents/$DOCUMENT_ID)
echo $RES
FETCHED_DOC64=$(echo "$RES" | jq -r .data)
FETCHED_TS=$(echo "$RES" | jq -r .timeStamp)
FETCHED_FROM=$(echo "$RES" | jq -r .fromMSP)
FETCHED_TO=$(echo "$RES" | jq -r .toMSP)
FETCHED_ID=$(echo "$RES" | jq -r .id)
echo "> $FETCHED_TS: id<$FETCHED_ID> $FETCHED_FROM -> $FETCHED_TO, document data b64 = '$FETCHED_DOC64'"

echo "###################################################"
echo "> fetching org1 signatures"
SIGNATURES=$(request "GET" "" http://$BSA_ORG1/signatures/$FETCHED_ID/ORG1)
ORG1_SIGNATURE=$(echo $SIGNATURES | jq -r .[].signature)
echo "> got ORG1 signature $ORG1_SIGNATURE"

echo "> verifying signature"
FETCHED_DOC=$(echo $FETCHED_DOC64 | openssl base64 -d)
echo -n $FETCHED_DOC > $DOC
echo $ORG1_SIGNATURE | openssl base64 -d | openssl dgst -sha256 -verify $PUB_ORG1 -signature /dev/stdin $DOC

echo "###################################################"
echo "> fetching org2 signatures"
SIGNATURES=$(request "GET" "" http://$BSA_ORG1/signatures/$FETCHED_ID/ORG2)
ORG2_SIGNATURE=$(echo $SIGNATURES | jq -r .[].signature)
echo "> got ORG2 signature $ORG2_SIGNATURE"

echo "> verifying signature"
echo -ne $DOCUMENT > $DOC
echo $ORG2_SIGNATURE | openssl base64 -d | openssl dgst -sha256 -verify $PUB_ORG2 -signature /dev/stdin $DOC
