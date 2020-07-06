# [BWRP] Atomic Setup  

## Kubernetes - Prerequisite

1. Have access to a pre-configured kubernetes node.
   You should be able to run "kubectl get nodes" showing "status" ready:
   
    ````
    > kubectl get nodes
    NAME             STATUS   ROLES    AGE    VERSION
    XXXXXX           Ready    master   1d     v1.18.0
    ````
    
2. configured DNS to your Server, eg "peer0.org1.example.com"

## Prepare your Pods

1. edit "setup.cfg" to suit your needs:
   | Variable | Value | Description |
   |----|---|---|
   | CFG_KUBENS | gsma | Namespace used in kubernetes. Highly recommended NOT to use default |
   | CFG_HOSTNAME | bwrp | The "xxx.< hostname >.xxx.xxx part |
   | CFG_DOMAIN | subdomain.yourdomain.com | The "xxx.xxx.< domain > part |
   | CFG_CA_ADMINPW | ##secret## | The CA Admin pw. Generate e.g. via openssl rand -base64 32|
   | CFG_CA_PEERPW | ##secret## | The CA peer user pw. Also generate...|
   | CFG_CA_PEERADMINPW | ##secret## | The CA peer admin pw. Also generate...|
   | CFG_CA_PORT | 7054 | Port number CA to be run on. Default is 7054.|
   | CFG_CA_C | GB | C = Country |
   | CFG_CA_ST | London | ST = StateOrProvinceName |
   | CFG_CA_L | London | L = LocalityName |
   | CFG_CA_O | Org1 | O = Organization |
   | CFG_CA_OU | WholesaleRoaming | OU = Organizational Unit |
   | CFG_ORG | Org1 | Name of your organization in the HLF network |
   | CFG_PEER_NAME | peer0 | The "< peer >.xxx.xxx.xxx part |
   | CFG_PEER_PORT | 7051 | Port number Hyperledger Peer to be run on. Default is 7051 |
   | CFG_PEER_ADMIN | 7051 | Port number Hyperledger Peer to be run on. Default is 7051 |
   | CFG_PEER_EXTERNAL_IP | 1.2.3.4 | An external IP that you want to asign to the kubernetes NodePort of the peer |
   | CFG_PV_PATH | /mnt/data | The Kubernetes Persistence Volume size. Can be resized later. |
   | CFG_PV_STORAGE_CLASS | gp2 | The storage class the cluster should use ("local-storage" = local, "gp2" = aws, ...) |
   | CFG_PV_SIZE | 10Gi | The Kubernetes Persistence Volume size. Can be resized later. |
   | CERT_SIGNER_URL | https://hldid.org/ejbca/certreq | The URL of the certificate signing service. |

2. execute "./setup.sh" and follow the instructions




