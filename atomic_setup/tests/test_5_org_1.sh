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

DOCUMENT=$1
DOCUMENT_ID=$2

function request {
    RET=$(curl -s -S -X $1 -H "Content-Type: application/json" -d "$2" "$3")
    echo $RET
    echo $RET | grep -i "error" > /dev/null && echo $RET > /dev/stderr && exit 1 || : 
}  

echo "###################################################"
echo "> fetching contract from $ORG_1_NAME_LOWERCASE"
RES=$(request "GET" "" $CFG_ORG_1_BLOCKCHAIN_ADAPTER_URL/private-documents/$DOCUMENT_ID)
echo $RES
FETCHED_DOC64=$(echo "$RES" | jq -r .data)
FETCHED_TS=$(echo "$RES" | jq -r .timeStamp)
FETCHED_FROM=$(echo "$RES" | jq -r .fromMSP)
FETCHED_TO=$(echo "$RES" | jq -r .toMSP)
FETCHED_ID=$(echo "$RES" | jq -r .id)
echo "> $FETCHED_TS: id<$FETCHED_ID> $FETCHED_FROM -> $FETCHED_TO, document data b64 = '$FETCHED_DOC64'"

echo "###################################################"
echo "> fetching $ORG_1_NAME_LOWERCASE signatures"
SIGNATURES=$(request "GET" "" $CFG_ORG_1_BLOCKCHAIN_ADAPTER_URL/signatures/$FETCHED_ID/${ORG_1_NAME_UPPERCASE}MSP)
ONE_SIGNATURE=$(echo $SIGNATURES | jq -r .[].signature)
echo "> got $ORG_1_NAME_LOWERCASE signature $ONE_SIGNATURE"

echo "> verifying $ORG_1_NAME_LOWERCASE signature"
FETCHED_DOC=$(echo $FETCHED_DOC64 | openssl base64 -d)
echo -n $FETCHED_DOC > $DOC
echo $ONE_SIGNATURE | openssl base64 -d | openssl dgst -sha256 -verify p_one -signature /dev/stdin $DOC

rm -rf p_one

echo "###################################################"
echo "> fetching $ORG_2_NAME_LOWERCASE signatures"
SIGNATURES=$(request "GET" "" $CFG_ORG_1_BLOCKCHAIN_ADAPTER_URL/signatures/$FETCHED_ID/${ORG_2_NAME_UPPERCASE}MSP)
TWO_SIGNATURE=$(echo $SIGNATURES | jq -r .[].signature)
echo "> got $ORG_2_NAME_LOWERCASE signature $TWO_SIGNATURE"

echo "add next as args on the test_6_org_2.sh"
echo "$DOCUMENT $TWO_SIGNATURE"
