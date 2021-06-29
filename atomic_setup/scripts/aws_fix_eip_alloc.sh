#!/bin/bash
set -e -o pipefail
. setup.cfg

PEER_EIP_TAG="BWRP_PEER_IP"

echo "> setting namespace"
kubectl config set-context --current --namespace=$CFG_KUBENS

echo "> fetching peer pod name"
POD=$(kubectl get po | grep ^${CFG_PEER_NAME}- | awk '{print $1}')

echo "> fetching internal ip of pod $POD"
INT_IP=$(kubectl -n $CFG_KUBENS exec $POD -c peer -- hostname -i)
echo "> got $INT_IP"

echo "> fetching network interface id"
INTERFACE_ID=$(aws ec2 describe-network-interfaces --filters Name=addresses.private-ip-address,Values=$INT_IP --query NetworkInterfaces[].NetworkInterfaceId --output text)
echo "> got $INTERFACE_ID"

echo "> fetching elastic ip alloc id for $PEER_EIP_TAG"
EIP_ALLOC_ID=$(aws ec2  describe-addresses --filter Name=tag:Name,Values=$PEER_EIP_TAG --query Addresses[].AllocationId --output text)
EIP_ALLOC_IP=$(aws ec2  describe-addresses --filter Name=tag:Name,Values=BWRP_PEER_IP --query Addresses[].PublicIp --output text)
echo "> got $EIP_ALLOC_ID (IP=$EIP_ALLOC_IP)"

#instance id: aws ec2 describe-instances  --filters Name=network-interface.addresses.private-ip-address,Values=$INT_IP --query Reservations[].Instances[].InstanceId
echo "> associating address $EIP_ALLOC_IP (ALLOC=$EIP_ALLOC_ID) to network if $INTERFACE_ID"
ASSOCIATION=$(aws ec2 associate-address  --network-interface-id=$INTERFACE_ID --allocation-id=$EIP_ALLOC_ID --private-ip-address $INT_IP --output text)

echo "> done, association ID=$ASSOCIATION"
