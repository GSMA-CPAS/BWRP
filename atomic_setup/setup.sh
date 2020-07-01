#!/bin/bash

#Kubernetes Namespace
KUBENS="default"


#apply to all
HOSTNAME="bwrp_sandbox" #"org1"
DOMAIN="dlhthub.telekom.net" #"example.com"

#CA config
CA_ADMINPW=$(openssl rand -base64 32)
CA_PORT="7054"
#CSR Details. C=Country, ST=State, L=Locale, O=Organizational, OU=Organizational Unit
#cannot leave empty, or else will break file generation
CA_C="DE" #"GB"
CA_ST="NRW" #"London"
CA_L="Bielefeld" #"London"
CA_O="DTBW" #"Org1"
CA_OU="WholesaleRoaming"

#peer Config
ORG="DTBW" #"Org1"
PORT="7050"

#Persistent Volume Size
PV_SIZE="10Gi"
#Local Persistance Volume Path. Will autho generate SUB DIR of <HOSTNAME>-<DOMAIN>
PV_PATH="/mnt/data/"

#FIXME: make this shorter, typing in the full name all the time when using kubectl is no fun...
MYHOST=${HOSTNAME}-$(echo $DOMAIN |awk '{gsub(/\./, "-");  print}')

CONFIG_PATH=./config
CONFIG_PATH_CA=$CONFIG_PATH/ca

CERT_SIGNER_URL=https://hldid.org/ejbca/certreq


# create paths:
mkdir -p $CONFIG_PATH
mkdir -p $CONFIG_PATH_CA