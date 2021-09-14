#!/bin/bash

function request {
    RET=$(curl -s -S -X $1 -H "Content-Type: application/json" -d "$2" "$3")
    echo $RET
    echo $RET | grep -i "error" > /dev/null && echo $RET > /dev/stderr && exit 1 || :
}

function setupSignCerts() {
  echo "> storing root cert on DTAG"
  request PUT "[\"$(cat ${PV_PATH}CA/ca-cert.pem | awk 1 ORS='\\n' )\"]" http://blockchain-adapter-${HOSTNAME}.${KUBENS}.svc.cluster.local:${BLOCKCHAIN_ADAPTER_PORT}/config/certificates/root
}

setupSignCerts