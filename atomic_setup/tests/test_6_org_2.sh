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
TWO_SIGNATURE=$2

echo "> verifying $ORG_2_NAME_LOWERCASE signature"
echo -ne $DOCUMENT > $DOC
echo $TWO_SIGNATURE | openssl base64 -d | openssl dgst -sha256 -verify p_two -signature /dev/stdin $DOC

rm -rf p_two
