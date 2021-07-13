#!/bin/bash
set -e -o pipefail
. setup.cfg 

POD=fabric-tools

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

function deploy() {
    CHAINCODE=$1

    cd ${CFG_CONFIG_PATH}/chaincode/
    tar cfz code.tar.gz connection.json
    tar cfz $CHAINCODE.tgz code.tar.gz metadata.json
    cd ../..
    kubectl cp ${CFG_CONFIG_PATH}/chaincode/$CHAINCODE.tgz $POD:/opt

    echo "> installing chaincode "
    kubectl exec $POD -- /opt/remote_cli.sh peer lifecycle chaincode install /opt/$CHAINCODE.tgz
}

function approve(){
    CHAINCODE_LABEL=$1

    PACKAGE_ID=$(kubectl exec $POD -- /opt/remote_cli.sh peer lifecycle chaincode queryinstalled |grep $CHAINCODE_LABEL)
    PACKAGE_ID="${PACKAGE_ID//Installed chaincodes on peer:/}"
    PACKAGE_ID="${PACKAGE_ID//Package ID: /}"
    PACKAGE_ID="${PACKAGE_ID//, Label: */}"

    INFO=$(kubectl exec $POD -- /opt/remote_cli.sh peer lifecycle chaincode querycommitted -o orderer.hldid.org:7050 --channelID ${CFG_CHANNEL_NAME} --name ${CFG_CHAINCODE_NAME_ONCHANNEL} --output json)

    VERSION=$(echo $INFO | jq -r '.version' )
    SEQUENCE=$(echo $INFO | jq '.sequence' )

    echo "> got package id $PACKAGE_ID"
    echo "> got version $VERSION, sequence $SEQUENCE"

    echo "> approving chaincode "
    kubectl exec $POD -- /opt/remote_cli.sh peer lifecycle chaincode approveformyorg --channelID ${CFG_CHANNEL_NAME} --name ${CFG_CHAINCODE_NAME_ONCHANNEL} --version $VERSION --package-id $PACKAGE_ID --sequence $SEQUENCE -o orderer.hldid.org:7050 --tls --cafile /opt/certs/tlsca.orderer.hldid.org-cert.pem --clientauth --keyfile /mnt/data/peer/peers/${CFG_PEER_NAME}.${CFG_HOSTNAME}.${CFG_DOMAIN}/tls/server.key --certfile /mnt/data/peer/peers/${CFG_PEER_NAME}.${CFG_HOSTNAME}.${CFG_DOMAIN}/tls/server.crt
}

function deploy_chaincode_pod(){
    CHAINCODE_LABEL=$1

    PACKAGE_ID=$(kubectl exec $POD -- /opt/remote_cli.sh peer lifecycle chaincode queryinstalled |grep $CHAINCODE_LABEL)
    PACKAGE_ID="${PACKAGE_ID//Installed chaincodes on peer:/}"
    PACKAGE_ID="${PACKAGE_ID//Package ID: /}"
    CFG_CHAINCODE_CCID="${PACKAGE_ID//, Label: */}"

    echo "> got package id $CFG_CHAINCODE_CCID"
    
    echo "> prepare deployment "

    TMP=$(mktemp)
    	IN=template/kubernetes/chaincode-pod.yaml
    	OUT=$CFG_CONFIG_PATH/kubernetes/chaincode-pod.yaml
    	cp -ar $IN $TMP
    	
    	echo "> generating $OUT..."
    
    	# replace all known vars
    	while IFS='' read -r line || [[ -n "$line" ]]; do
    		for varname in ${!CFG_*}; do
    			KEY="${varname:4}";
    			VAL="${!varname}";
    			line="${line//\$\{$KEY\}/$VAL}"
    		done;
    		echo "$line"
        done < "$TMP" > "$OUT"

    echo "> deploying chaincode pod and svc"
    kubectl apply -f ${CFG_CONFIG_PATH}/kubernetes/chaincode-svc.yaml
    kubectl apply -f ${CFG_CONFIG_PATH}/kubernetes/chaincode-pod.yaml    

}

deploy ${CFG_CHAINCODE_NAME_ONCHANNEL} 
approve ${CFG_CHAINCODE_NAME_ONCHANNEL}
deploy_chaincode_pod ${CFG_CHAINCODE_NAME_ONCHANNEL}
