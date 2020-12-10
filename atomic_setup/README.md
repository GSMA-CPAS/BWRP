# [BWRP] Atomic Setup  

## Kubernetes - Prerequisite

1. Have access to a pre-configured kubernetes node on our machine.
   You should be able to run "kubectl get nodes" showing "status" ready:
   
    ````
    > kubectl get nodes
    NAME             STATUS   ROLES    AGE    VERSION
    <Hostname>       Ready    master   1d     v1.18.0
    
2. Get public DNS configured pointing to your Server, eg "<CFG_PEER_NAME.CFG_HOSTNAME.CFG_DOMAIN>" to your Server IP.
   For example: "peer0.org1.example.com" - "org1" should be the four character mspid allocated to your setup by GSMA.
   In case you are using AWS instance, it should point to your Server's Public IP.

## Prepare your Pods

1. edit "setup.cfg" to suit your needs:
   | Variable | Value | Description |
   |----|---|---|
   | CFG_KUBENS | gsma | Namespace to be used in kubernetes. Highly recommended NOT to use default |
   | CFG_HOSTNAME | bwrp | E.g., The "CFG_PEER_NAME.<hostname>.CFG_DOMAIN" part. Hostname of the kubernetes cluster master machine |
   | CFG_DOMAIN | subdomain.yourdomain.com | The "CFG_PEER_NAME.CFG_HOSTNAME.<domain>" part |
   | CFG_CA_ADMINPW | ##secret## | The CA Admin pw. Generate e.g. via openssl rand -base64 32 (Make sure password is URL safe) |
   | CFG_CA_PEERPW | ##secret## | The CA peer user pw. Also generate e.g. via openssl rand -base64 32 (Make sure password is URL safe) |
   | CFG_CA_PEERADMINPW | ##secret## | The CA peer admin pw. Also generate e.g. via openssl rand -base64 32 (Make sure password is URL safe) |
   | CFG_CA_PORT | 7054 | Port number CA to be run on. Default is 7054 |
   | CFG_CA_C | GB | C = Country of organization |
   | CFG_CA_ST | London | ST = StateOrProvinceName of organization |
   | CFG_CA_L | London | L = LocalityName of organization |
   | CFG_CA_O | Org1 | O = Organization Name (4 Character length) |
   | CFG_CA_OU | WholesaleRoaming | OU = Organizational Unit |
   | CFG_ORG | Org1 | Name of your organization in the HLF network (4 Character length. Can be same as CFG_CA_O) |
   | CFG_PEER_NAME | peer0 | The "<peer>.CFG_HOSTNAME.CFG_DOMAIN" part |
   | CFG_PEER_PORT | 7050 | Port number Hyperledger Peer to be run on. Default is 7050 - Make sure this port is whitelisted and can be accessed from outside on your machine |
   | CFG_PEER_EXTERNAL_IP | 1.2.3.4 | An external IP that you want to asign to the kubernetes NodePort of the peer - Server IP. (Not public IP) in case AWS instance is used |
   | CFG_PEER_TLS_USERNAME | mtlsuser | The user used for mTLS |
   | CFG_PEER_TLS_USERPW   | ##swecret## | The password of the mTLS user |
   | CFG_PV_PATH | /mnt/data | The Kubernetes Persistence Volume size. Can be resized later. |
   | CFG_PV_STORAGE_CLASS | gp2 | The storage class the cluster should use ("local-storage" = local, "gp2" = aws, ...) |
   | CFG_PV_SIZE | 10Gi | The Kubernetes Persistence Volume size. Can be resized later. |
   | CERT_SIGNER_URL | https://hldid.org/ejbca/certreq | The URL of the certificate signing service. |
   | CFG_OFFCHAIN_REST_PORT | 3333 | The offchain rest port. |
   | CFG_OFFCHAIN_MYSQL_ROOT_PASSWORD | changeThisRootPassword | The root password for mysql. |
   | CFG_OFFCHAIN_MYSQL_DB | odba | The offchain db name. |
   | CFG_OFFCHAIN_MYSQL_USER | odba | The offchain db user. |
   | CFG_OFFCHAIN_MYSQL_PASSWORD | changeThisPassword | The user password for mysql.. |
   | CFG_MYSQL_SERVER_PORT | 3306 | Mysql port. |
   | CFG_BLOCKCHAIN_ADAPTER_PORT | 8081 | The blockchain adapter port. |
   | CFG_WEBAPP_MYSQL_ROOT_PASSWORD | changeThisRootPassword | The root password for mysql. |
   | CFG_WEBAPP_MYSQL_DB | nomad | The webapp db name. |
   | CFG_WEBAPP_MYSQL_USER | nomad | The webapp db user. |
   | CFG_WEBAPP_MYSQL_PASSWORD | changeThisPassword | The user password for mysql. |
   | CFG_WEBAPP_MYSQL_SERVER_PORT | 3306 | Mysql port. |
   | CFG_WEBAPP_PORT | 3000 | The webapp port. |
   | CFG_NGINX_HTTP2_PORT | 4443 | Nginx http 2 port. |
   | CFG_NGINX_HTTPS_PORT | 443 | Nginx https service port. |
   | CFG_NGINX_NODE_PORT | 30443 | Nginx node port. |
   | CFG_NGINX_HTTP_PORT | 80 | Nginx port for issuing certs |
   | CFG_NGINX_CERT_NODE_PORT | 30080 |  node port for issuing certs |

2. Register record host_name.domain in DNS to point to pubilc IP address.

3. Execute "./setup.sh" and follow the instructions

   NOTE:- You will be asked for Username and Password. Request channel administrator to provide the same. These credentials are required to get Certificates
   signed by CERT_SIGNER_URL authority

4. After successful executiong of the script, Email deployment/pvc/ca/${ORG}.json to the channel admin
5. Wait for inclusion to the channel (email from admin)
6. (optional) If you are on aws, edit and run "scripts/aws_fix_eip_alloc.sh" in order to fix the EIP allocation on AWS
7. Execute "scripts/join_channel.sh mychannel" command, you should get a sucess message and the list of joined channels should include mychannel
8. Deploy the chaincodes via scripts/deploy_chaincodes.sh
9. Enter webapp at https://host_name.domain with username: password  admin:admin.

## Pods
There are various pods deployed that are needed during operation. 
The two pods fabric-tools and fabric-ca-tools are just needed during deploymend and testing, those should be removed in a production system once installed.

## Directories
After the first run of setup.sh you will end up with the following directories:

* deployment/certs -> Your signed certificats and the *private key*. Create a backup and handle those with care!
* deployment/pvc/ca -> a backup of the PVC as deployed on your ca pod, backup this as well! This contains your HLF crypto blobs.
* deployment/config -> various configuration files that have been generated from the templates
* deployment/kubernetes -> kubernetes yaml files that have been generated from the templates
* deployment/scripts -> various scripts that have been generated from the templates

## CI/CD
If you plan to deploy this setup in a CI/CD pipeline all you have to do is:

1. check out this source tree
2. overlay your setup.cfg file [do not keep this in a repository as it contains secrets!]
3. add the deployment/certs directory from your backup [contains certificates. do not check this in]
4. add the deployment/pvc/ca directory from your backup [contains hlf crypto secrets. do not check this in]
5. run setup.sh

The important steps are 3.+4. as those contain all your secrets and authorization information

## HYBRID APROACH INTEGRATION 

Hybrid installation has been integrated into the "Prepare your Pods" step.

If you upgrade from a previous setup, please follow the steps:
1. Deploy the hybrid chaincode via scripts/deploy_chaincodes.sh
2. Edit setup.cfg config file sections for blockchain and offchain-db adapters
3. run ./scripts/prepare_templates.sh
4. Apply a secret to access private docker REPO
run kubectl apply -f deployment/kubernetes/registry-secret.yaml
5. Generate TLS user certs
run ./scripts/generate_crypto_mtls.sh
6. Deploy Offchain DB
run ./scripts/deploy_offchain_couchdb.sh
7. Deploy Blockchain Adapter
7.1. run ./scripts/generate_ccp_hybrid.sh
7.2. run ./scripts/deploy_blockchain_adapter.sh

If you start from scratch, this is not necessary as setup.sh will invoke it for you!

# For testing
1. Configure the following variables in tests/test_setup.cfg:
   | Variable | Description |
   |----|---|
   | ORG_NAME_1 | The name of your organization |
   | ORG_HOSTNAME_1 | The hostname of your organization |
   | ORG_NAME_2 | The name of the partner organization |
   | ORG_HOSTNAME_2 | The hostname of the partner organization |

2. upload test files to your organization by using ./scripts/deploy_tests.sh
3. upload test files for the partner organization by using ./scripts/deploy_tests.sh
4. on your org run kubectl exec fabric-tools /opt/tests/test_1_org_1.sh and follow the instructions at the end of the script
 - on org1 site the scrits that have to run are: test_1_org_1.sh, test_3_org_1.sh, test_5_org_1.sh
 - on org2 site the scrits that have to run are: test_2_org_2.sh, test_4_org_2.sh

## FRONTEND
If you start from scratch, this is not necessary as setup.sh will invoke it for you!

If you upgrade from a previous setup, please follow the steps:
1. Configure the following variables in setup.cfg:
   | Variable | Value | Description |
   |----|---|---|
   | CFG_WEBAPP_MYSQL_ROOT_PASSWORD | changeThisRootPassword | The root password for mysql. |
   | CFG_WEBAPP_MYSQL_DB | nomad | The webapp db name. |
   | CFG_WEBAPP_MYSQL_USER | nomad | The webapp db user. |
   | CFG_WEBAPP_MYSQL_PASSWORD | changeThisPassword | The user password for mysql. |
   | CFG_WEBAPP_MYSQL_SERVER_PORT | 3306 | Mysql port. |
   | CFG_WEBAPP_PORT | 3000 | The webapp port. |
   | CFG_NGINX_HTTP2_PORT | 4443 | Nginx http 2 port. |
   | CFG_NGINX_HTTPS_PORT | 443 | Nginx https service port. |
   | CFG_NGINX_NODE_PORT | 30443 | Nginx node port. |
   | CFG_NGINX_HTTP_PORT | 80 | Nginx port for issuing certs |
   | CFG_NGINX_CERT_NODE_PORT | 30080 |  node port for issuing certs | 
   | CFG_NGINX_CERT_MAIL | setYour@mail.here | Mail used for letsencrypt cert |

2. Register record host_name.domain in DNS to point to pubilc IP address.
3. run ./scripts/prepare_templates.sh setup.cfg deployment
4. run ./scripts/prepare_webapp_config.sh
5. run ./scripts/deploy_frontend_certbot.sh
6. run ./scripts/deploy_frontend_webapp.sh
7. run ./scripts/deploy_frontend_nginx.sh
8. Enter webapp at https://host_name.domain with username: password  admin:admin.
9. To renew certs for Nginx:
   run ./scripts/renew_nginx_certs.sh

## TODO
The CCP parts and the Chaincode parts are not yet transfered to the proposed scheme.
