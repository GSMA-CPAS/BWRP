#!/bin/bash
. setup.sh

# process all template files
for dir in $(ls template); do
  output_dir=$CONFIG_PATH/$dir
  mkdir -p $output_dir
  for input in $(ls template/$dir); do
    output=$output_dir/$input
    echo "> processing template/$dir/$input -> $output"
    envsubst < template/$dir/$input > $output
  done
done
exit
echo "> deploying persistant volume"
kubectl -n $KUBENS apply -f generated_config/kubernetes/storage-pv.yaml
PVC=$(kubectl get pods | grep xxx | awk '{print $1}')
kubectl -n $KUBENS wait --timeout=5m --for=condition=ready pv/$PVC
exit


echo "Step 2 [Deploy Certificate Authority]"
if [ -f "${MYHOST}-ca.yaml" ]; then
    echo "WARN> Existing deployment file [${MYHOST}-ca.yaml] exist. Not creating new one."
    echo "WARN> To generate, please remove the exiting file."
    echo
else

    generateFromTemplate ca $MYHOST $HOSTNAME $DOMAIN $CA_PORT $KUBENS $CA_ADMINPW > ${MYHOST}-ca.yaml
    echo "[${MYHOST}-ca.yaml] generated."
    echo
fi

mkdir -p "${PV_PATH}${MYHOST}-pv-volume/CA/"
  if [ -f "${PV_PATH}${MYHOST}-pv-volume/CA/fabric-ca-server.db" ]; then
    echo "Warning. Existing CA Config and Cert found. at [${PV_PATH}${MYHOST}-pv-volume/CA/]"
    echo "Please make sure to remove them and regenerate. Or else, TLS cert will get mixed up."
    echo
    exit 1;
  fi



if [ -f "${PV_PATH}${MYHOST}-pv-volume/CA/ca-cert.pem" ]; then
    echo "WARN>  Existing Signed Intermediate Cert Exist."
    echo "       If you wish to regenerate a new one, please delete"
    echo "       ["${PV_PATH}${MYHOST}-pv-volume/CA/ca.csr"]"
    echo "       ["${PV_PATH}${MYHOST}-pv-volume/CA/priv_key.pem"]"
    echo "       ["${PV_PATH}${MYHOST}-pv-volume/CA/ca-cert.pem"]"
    echo
    echo "       If you do this, please requst for a new \"Username/Password\" to generate new certificates"
    echo
else
    read -p "Please enter Username:`echo $'\n> '`" user
    read -p "Please enter Password:`echo $'\n> '`" pass

    openssl ecparam -name prime256v1 -genkey -noout -out ${PV_PATH}${MYHOST}-pv-volume/CA/priv_key.pem > /dev/null 2>&1
    echo "Private key generated [${PV_PATH}${MYHOST}-pv-volume/CA/priv_key.pem]"
    openssl req -new -sha256 -key ${PV_PATH}${MYHOST}-pv-volume/CA/priv_key.pem -out ${PV_PATH}${MYHOST}-pv-volume/CA/ca.csr -subj "/C=${CA_C}/ST=${CA_ST}/L=${CA_L}/O=${CA_O}/OU=${CA_OU}/CN=ca.${HOSTNAME}.${DOMAIN}/2.5.4.41=${ORG}MSP" > /dev/null 2>&1

    echo "CSR generated [${PV_PATH}${MYHOST}-pv-volume/CA/ca.csr]"

    echo
    echo "Requesting for Certificate with CSR"
    echo
    curl -v -k -X POST https://hldid.org/ejbca/certreq -F"user=${user}" -F"password=${pass}" -F"pkcs10file=@${PV_PATH}${MYHOST}-pv-volume/CA/ca.csr" -F"resulttype=1" --output ${PV_PATH}${MYHOST}-pv-volume/CA/ca-cert.pem > /dev/null 2>&1

    openssl x509 -in ${PV_PATH}${MYHOST}-pv-volume/CA/ca-cert.pem -text > /dev/null 2>&1
    if [ "$?" -ne 0 ]; then
        echo "ERROR> Unable to receive Certificate. Please contact the Administrator"
        echo
        echo "======================="
        sed -n '113,115p' < ${PV_PATH}${MYHOST}-pv-volume/CA/ca-cert.pem
        echo "======================="
        rm ${PV_PATH}${MYHOST}-pv-volume/CA/ca-cert.pem
        rm ${PV_PATH}${MYHOST}-pv-volume/CA/priv_key.pem
        rm ${PV_PATH}${MYHOST}-pv-volume/CA/ca.csr
        exit 1
    fi

    echo "Signed Certificate received [${PV_PATH}${MYHOST}-pv-volume/CA/ca-cert.pem]"
    cp ./template/ca-chain.pem ${PV_PATH}${MYHOST}-pv-volume/CA/
    cat ${PV_PATH}${MYHOST}-pv-volume/CA/ca-cert.pem >> ${PV_PATH}${MYHOST}-pv-volume/CA/ca-chain.pem
    echo
fi


generateFromTemplate ca-config $HOSTNAME $DOMAIN $CA_ADMINPW $CA_C $CA_ST $CA_L $CA_O ${CA_OU} > ${PV_PATH}${MYHOST}-pv-volume/CA/fabric-ca-server-config.yaml
echo "  Kubernetes Deployment file [${MYHOST}-ca.yaml] created."
echo "  Apply generated deployment files to your cluster "
echo "  'kubectl apply -f ${MYHOST}-ca.yaml'"
echo
echo

echo "Please make sure pod is running."
echo "kubectl get pods --selector=io.kompose.service=ca-$MYHOST -o=wide -n $KUBENS"
echo
echo "Get the 'ca' IP address and add it to your /etc/hosts as (using below cmd, labeld as 'CLUSTER-IP')"
echo "kubectl get svc --selector=io.kompose.service=ca-$MYHOST -o=wide -n $KUBENS"
echo "XXX.XXX.XXX.XXX	ca-$MYHOST.local"
echo

echo
echo "Continue to execute './step2.sh' for further instructions"
echo
echo
