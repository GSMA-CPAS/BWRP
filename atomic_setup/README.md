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
3. email deployment/pvc/ca/${ORG}.json to the channel admin
4. wait for inclusion to the channel (email from admin)
5. (optional) if you are on aws, edit and run scripts/aws_fix_eip_alloc.sh in order to fix the EIP allocation on AWS
6. execute scripts/join_channel.sh, you should get a sucess message and the list of joined channels should include mychannel
7. play around with scripts/remote_cli.sh peer channel list etc

## Pods
There are a various pods deployed that are needed during operation. 
The two pods fabric-tools and fabric-ca-tools are just needed during deploymend and testing, those should be removed in a production system once installed.

## Directories
After the first run of setup.sh you will end up with the following directories:

* deployment/certs -> Your signed certificats and the *private key*. Create a backup and handle those with care!
* deployment/pvc/ca -> a backup of the PVC as deployed on your ca pod, backup this as well! This contains your HLF crypto blobs.
* deployment/config -> various configuration files that have been generated from the templates
* deployment/kubernetes -> kubernetes yaml files that have been generated from the templates
* deployment/scripts.sh -> various scripts that have been generated from the templates

## CI/CD
If you plan to deploy this setup in a CI/CD pipeline all you have to do is:

1. check out this source tree
2. overlay your setup.cfg file [do not kee this in a repository as it contains secrets!]
3. add the deployment/certs directory from your backup [contains certificates. do not check this in]
4. add the deployment/pvc/ca directory from your backup [contains hlf crypto secrets. do not check this in]
5. run setup.sh

The important steps are 3.+4. as those contain all your secrets and authorization information

## TODO
The CCP parts and the Chaincode parts are not yet transfered to the proposed scheme.
