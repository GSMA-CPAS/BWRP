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

# create a unique document if not passed via command line
[ -z "$DOCUMENT" ] && DOCUMENT=$(date +%s) 

DOCUMENT64=$(echo $DOCUMENT | openssl base64 | tr -d '\n')
DOCUMENTSHA256=$(echo -n $DOCUMENT64 | openssl dgst -sha256 -r | cut -d " " -f1)
echo "> calculated hash $DOCUMENTSHA256 for document"

# generate crypto material:
DIR=$(mktemp -d)
KEY=$DIR/KEY
CRT=$DIR/CRT
PUB_ONE=$DIR/PUB_ONE
PUB_TWO=$DIR/PUB_TWO
DOC=$DIR/DOC
# make sure to remove temp files on exit
trap "{ rm -fr $DIR; }" EXIT

function request {
    RET=$(curl -s -S -X $1 -H "Content-Type: application/json" -d "$2" "$3")
    echo $RET
    echo $RET | grep -i "error" > /dev/null && echo $RET > /dev/stderr && exit 1 || : 
}  

echo "###################################################"
# echo "> setting rest uri on $ORG_1_NAME_LOWERCASE"
# request "PUT" '{"restURI": "'$CFG_ORG_1_OFFCHAIN_URL'"}' $CFG_ORG_1_BLOCKCHAIN_ADAPTER_URL/config/offchain-db-adapter

echo "send to org_2 to add next as args on the test_2_org_2.sh"
echo "$DOCUMENT64 $DOCUMENT"
