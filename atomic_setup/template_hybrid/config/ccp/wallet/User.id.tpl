 {
    "_COMMENT_" : "",

    "credentials":{
         "certificate":"from_pem:deployment/pvc/ca/users/User@${HOSTNAME}.${DOMAIN}/tls/server.crt",
         "privateKey" : "from_pem:deployment/pvc/ca/users/User@${HOSTNAME}.${DOMAIN}/tls/server.key"
    },
    "mspId" : "${ORG}MSP",
    "type":"X.509",
    "version":1
}