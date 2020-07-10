#!/bin/bash

. setup.sh

read -n 1 -p "You are about to delete all Config and start fresh!
Press [Y] to continue or any key to stop:`echo $'\n> '`" sel
if [[ "$sel" == "y" ]] || [[ "$sel" == "Y" ]]; then
    echo
    echo "- removing [${PV_PATH}${MYHOST}-pv-volume/peer/peers/peer0.${HOSTNAME}.${DOMAIN}/]"
    rm -rf ${PV_PATH}${MYHOST}-pv-volume/peer/peers/peer0.${HOSTNAME}.${DOMAIN}/
    echo "- removing [${PV_PATH}${MYHOST}-pv-volume/peer/users/Admin@${HOSTNAME}.${DOMAIN}/]"
    rm -rf ${PV_PATH}${MYHOST}-pv-volume/peer/users/Admin@${HOSTNAME}.${DOMAIN}/
    echo "- removing [${PV_PATH}${MYHOST}-pv-volume/CA/*]"
    rm -rf ${PV_PATH}${MYHOST}-pv-volume/CA/*
    kubectl delete -f ${MYHOST}-ca.yaml
    rm ${MYHOST}-ca.yaml
    kubectl delete -f ${MYHOST}-peer0.yaml
    rm ${MYHOST}-peer0.yaml
    kubectl delete -f ${MYHOST}-pv.yaml
    rm ${MYHOST}-pv.yaml
    rm -rf fabric-ca-client
fi
echo
