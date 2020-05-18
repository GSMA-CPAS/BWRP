# [BWRP] Atomic Setup  
**Kubernetes**

-Prerequisite
-->Have access to a pre-configured kubernetes node.
-->Able to run "kubectl " showing "status" ready.

    # kubectl get nodes
    NAME             STATUS   ROLES    AGE    VERSION
    XXXXXX           Ready    master   1d     v1.18.0

--> configured DNS to your Server, eg "peer0.org1.example.com"


-Join Network
-->Configure "setup.sh"
 - **KUBENS**="default" #Namespace used in Kubernetes. Defaults to "default"
 - **HOSTNAME**="org1" #The "xxxx.< hostname >.xxx.xxx part
 - **DOMAIN**="example.com" #The "xxx.xxxx.yourdomain.com part
 - **CA_ADMINPW**=$(uname -a | md5sum |awk '{print $1}') #The first "Admin" user's password to your "CA". This is auto generated, or can be preset.
 - **CA_PORT**="7054" #Port number CA to be run on. Default is 7054.
 - **CA_C**="GB" # C=Country
 - **CA_ST**="London" # ST=State
 - **CA_L**="London" # L=Locale
 - **CA_O**="Org1" # O=Organizational
 - **CA_OU**="WholesaleRoaming" # OU=Organizational Unit
 - **ORG**="Org1" # Name of your organization.
 - **PORT**="7050" # Port number Hyperledger Peer to be run on. Default is 7050
 - **PV_SIZE**="10Gi" #The Kubernetes Persistence Volume size. Can be resized later.
 - **PV_PATH**="/mnt/data/" #absolute path to a empty directory with the defined capacity.


--> execute "./step1.sh"
follow the on-screen instruction.

-Start from begining
running this will clear all Certificate and config accordingly.
--> ./removeConfig.sh

**Docker-compose**
  Coming soon 



