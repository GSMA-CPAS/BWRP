{
    "name": "${ORG}-${HOSTNAME}",
    "version": "1.0.0",
    "client": {
        "organization": "${ORG}",
        "connection": {
            "timeout": {
                "peer": {
                    "endorser": "300"
                }
            }
        }
    },
    "organizations": {
        "${ORG}": {
            "mspid": "${ORG}MSP",
            "peers": [
                "peer0.${HOSTNAME}.${DOMAIN}:${PEER_PORT}"
            ],
            "certificateAuthorities": [
                "ca.${HOSTNAME}.${DOMAIN}"
            ],
            "adminPrivateKey": {
                "pem": "from_pem:deployment/pvc/ca/users/Admin@${HOSTNAME}.${DOMAIN}/msp/keystore/priv_sk"
            },
            "signedCert":{
                "pem": "from_pem:deployment/pvc/ca/users/Admin@${HOSTNAME}.${DOMAIN}/msp/signcerts/Admin@${HOSTNAME}.${DOMAIN}-cert.pem"
            }
        }
    },
    "orderers": {
        "orderer.hldid.org": {
            "url": "grpcs://orderer.hldid.org:7050",
            "tlsCACerts": {
                "pem": "from_pem:certs/gsma/orderer/tlsca.orderer.hldid.org-cert.pem"
            }
        },
        "orderer2.hldid.org": {
            "url": "grpcs://orderer2.hldid.org:7050",
            "tlsCACerts": {
                "pem": "from_pem:certs/gsma/orderer/tlsca.orderer.hldid.org-cert.pem"
            }
        }
    },
    "peers": {
        "peer0.${HOSTNAME}.${DOMAIN}:${PEER_PORT}": {
            "url": "grpcs://peer0.${HOSTNAME}.${DOMAIN}:${PEER_PORT}",
            "tlsCACerts": {
                "pem": "from_pem:deployment/pvc/ca/peers/peer0.${HOSTNAME}.${DOMAIN}/msp/tlscacerts/tlsca.${HOSTNAME}.${DOMAIN}-cert.pem"
            },
            "grpcOptions": {
                "ssl-target-name-override": "peer0.${HOSTNAME}.${DOMAIN}",
                "hostnameOverride": "peer0.${HOSTNAME}.${DOMAIN}"
            }
        }
    },
    "certificateAuthorities": {
        "ca.${HOSTNAME}.${DOMAIN}": {
            "url": "https://ca-${MYHOST}.${KUBENS}:${CA_PORT}",
            "caName": "ca.${HOSTNAME}.${DOMAIN}",
            "tlsCACerts": {
                "pem": "from_pem:deployment/ca/tls-cert.pem"
            },
            "httpOptions": {
                "verify": false
            }
        }
    }
}
