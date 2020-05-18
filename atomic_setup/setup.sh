#!/bin/bash

#Kubernetes Namespace
KUBENS="default"


#apply to all
HOSTNAME="org1"
DOMAIN="example.com"

#CA config
CA_ADMINPW=$(uname -a | md5sum |awk '{print $1}')
CA_PORT="7054"
#CSR Details. C=Country, ST=State, L=Locale, O=Organizational, OU=Organizational Unit
#cannot leave empty, or else will break file generation
CA_C="GB"
CA_ST="London"
CA_L="London"
CA_O="Org1"
CA_OU="WholesaleRoaming"

#peer Config
ORG="Org1"
PORT="7050"

#Persistent Volume Size
PV_SIZE="10Gi"
#Local Persistance Volume Path. Will autho generate SUB DIR of <HOSTNAME>-<DOMAIN>
PV_PATH="/mnt/data/"


MYHOST=${HOSTNAME}-$(echo $DOMAIN |awk '{gsub(/\./, "-");  print}')
