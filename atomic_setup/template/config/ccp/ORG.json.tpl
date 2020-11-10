{

    "_COMMENT_" : "",

    "name": "${ORG}",
    "version": "1.0.0",
    "config": {
        "discoveryOptions" : {
            "enabled" : true,
            "asLocalhost" : false
        },
        "walletPath" : "wallet/",
        "user" : "Admin",
        "channelName": "mychannel",
        "contractID": "hybrid"
    },
    "client": {
        "tlsEnable": true,
        "clientTlsIdentity": "mtls",
        "logging" : {
            "level": "debug"
        },
        "organization": "${HOSTNAME}",
        "connection": {
            "timeout": {
                "peer": {
                    "endorser": "300"
                }
            }
        }
    },
    "organizations": {
        "${HOSTNAME}": {
            "mspid": "${ORG}MSP",
            "users" : {
            },
            "peers": [
              "${PEER_NAME}.${HOSTNAME}.${DOMAIN}:${PEER_PORT}"
            ]
        }
    },
    "peers": {
        "${PEER_NAME}.${HOSTNAME}.${DOMAIN}:${PEER_PORT}": {
            "url": "grpcs://${PEER_NAME}.${HOSTNAME}.${DOMAIN}:${PEER_PORT}",
            "tlsCACerts": {
                "pem": "from_pem:deployment/pvc/ca/peers/${PEER_NAME}.${HOSTNAME}.${DOMAIN}/msp/tlscacerts/tlsca.${HOSTNAME}.${DOMAIN}-cert.pem"
            },
            "grpcOptions": {
                "ssl-target-name-override": "${PEER_NAME}.${HOSTNAME}.${DOMAIN}",
                "hostnameOverride": "${PEER_NAME}.${HOSTNAME}.${DOMAIN}"
            }
        }
    }
}
