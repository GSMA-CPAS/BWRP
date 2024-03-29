#!/bin/bash
. setup.sh

function one_line_pem {
    echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' $1`"
}

function json_ccp {
    local PP=$(one_line_pem ${PV_PATH}${MYHOST}-pv-volume/peer/peers/peer0.${HOSTNAME}.${DOMAIN}/msp/tlscacerts/tlsca.${HOSTNAME}.${DOMAIN}-cert.pem)
    local CP=$(one_line_pem ${PV_PATH}${MYHOST}-pv-volume/CA/tls-cert.pem)
    local AKP=$(one_line_pem ${PV_PATH}${MYHOST}-pv-volume/peer/users/Admin@${HOSTNAME}.${DOMAIN}/msp/keystore/priv_sk)
    local ACP=$(one_line_pem ${PV_PATH}${MYHOST}-pv-volume/peer/users/Admin@${HOSTNAME}.${DOMAIN}/msp/signcerts/Admin@${HOSTNAME}.${DOMAIN}-cert.pem)
    local kubens=${KUBENS}
    local myhost=${MYHOST}

    sed -e "s/\${MSPID}/$1MSP/g" \
        -e "s/\${ORG}/$1/g" \
        -e "s/\${HOSTNAME}/$2/g" \
        -e "s/\${DOMAIN}/$3/g" \
        -e "s/\${PORT}/$4/g" \
        -e "s/\${CAPORT}/$5/g" \
        -e "s#\${KUBENS}#$kubens#" \
        -e "s#\${MYHOST}#$myhost#" \
        -e "s#\${PEERPEM}#$PP#" \
        -e "s#\${CAPEM}#$CP#" \
        -e "s#\${ADMINKEYPEM}#$AKP#" \
        -e "s#\${ADMINCRTPEM}#$ACP#" \
        template/template-ccp.json
}

function yaml_ccp {
    local PP=$(one_line_pem ${PV_PATH}${MYHOST}-pv-volume/peer/peers/peer0.${HOSTNAME}.${DOMAIN}/msp/tlscacerts/tlsca.${HOSTNAME}.${DOMAIN}-cert.pem)
    local CP=$(one_line_pem ${PV_PATH}${MYHOST}-pv-volume/CA/tls-cert.pem)

    sed -e "s/\${MSPID}/$1MSP/g" \
        -e "s/\${ORG}/$1/g" \
        -e "s/\${HOSTNAME}/$2/g" \
        -e "s/\${DOMAIN}/$3/g" \
        -e "s/\${PORT}/$4/g" \
        -e "s/\${CAPORT}/$5/g" \
        -e "s#\${PEERPEM}#$PP#" \
        -e "s#\${CAPEM}#$CP#" \
        template/template-ccp.yaml
}


json_ccp $ORG $HOSTNAME $DOMAIN $PORT $CA_PORT $ORD_DOMAIN $ORD_HOSTNAME1 $ORD_PORT1 $ORD_HOSTNAME2 $ORD_PORT2 $PEERPEM $CAPEM > ${PV_PATH}${MYHOST}-pv-volume/peer/connection-${DOMAIN}.json
yaml_ccp $ORG $HOSTNAME $DOMAIN $PORT $CA_PORT $ORD_DOMAIN $ORD_HOSTNAME1 $ORD_PORT1 $ORD_HOSTNAME2 $ORD_PORT2 $PEERPEM $CAPEM > ${PV_PATH}${MYHOST}-pv-volume/peer/connection-${DOMAIN}.yaml

echo "Common Connection Profiles created at "
echo "[${PV_PATH}${MYHOST}-pv-volume/peer/connection-${DOMAIN}.json]"
echo "[${PV_PATH}${MYHOST}-pv-volume/peer/connection-${DOMAIN}.yaml]"
echo
