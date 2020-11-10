 {
    "credentials":{
         "certificate": "from_pem:deployment/pvc/ca/users/${CA_PEER_TLS_USERNAME}@${HOSTNAME}.${DOMAIN}/tls/server.crt",
         "privateKey" : "from_pem:deployment/pvc/ca/users/${CA_PEER_TLS_USERNAME}@${HOSTNAME}.${DOMAIN}/tls/server.key"
    },
    "mspId" : "${ORG}MSP",
    "type":"X.509",
    "version":1
}
