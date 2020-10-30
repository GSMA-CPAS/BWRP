 {
    "credentials":{
         "certificate":"from_pem:deployment/pvc/ca/users/Admin@${HOSTNAME}.${DOMAIN}/msp/signcerts/Admin@${HOSTNAME}.${DOMAIN}-cert.pem",
         "privateKey" : "from_pem:deployment/pvc/ca/users/Admin@${HOSTNAME}.${DOMAIN}/msp/keystore/priv_sk"
    },
    "mspId" : "${ORG}MSP",
    "type":"X.509",
    "version":1
}
