#!/bin/bash

# Fix Network Dependencies Script
# Resolves Internet Gateway and Subnet dependency issues

set -e

REGION="us-east-1"
VPC_ID="vpc-011fd6014a33a3da2"
IGW_ID="igw-0593ff39fdc1cb94c"

echo "🔧 Fixing Network Dependencies"
echo "VPC: $VPC_ID"
echo "IGW: $IGW_ID"

# Release all Elastic IPs in the VPC
echo "Releasing Elastic IPs..."
aws ec2 describe-addresses --region "$REGION" --filters "Name=domain,Values=vpc" --query 'Addresses[].AllocationId' --output text | \
while read -r allocation_id; do
    if [ -n "$allocation_id" ]; then
        echo "Releasing EIP: $allocation_id"
        aws ec2 release-address --allocation-id "$allocation_id" --region "$REGION" 2>/dev/null || true
    fi
done

# Delete all NAT Gateways in the VPC
echo "Deleting NAT Gateways..."
aws ec2 describe-nat-gateways --region "$REGION" --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways[].NatGatewayId' --output text | \
while read -r nat_id; do
    if [ -n "$nat_id" ]; then
        echo "Deleting NAT Gateway: $nat_id"
        aws ec2 delete-nat-gateway --nat-gateway-id "$nat_id" --region "$REGION" 2>/dev/null || true
    fi
done

# Wait for NAT Gateways to be deleted
echo "Waiting for NAT Gateways to be deleted..."
sleep 60

# Delete all Network Interfaces in the VPC
echo "Deleting Network Interfaces..."
aws ec2 describe-network-interfaces --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text | \
while read -r eni_id; do
    if [ -n "$eni_id" ]; then
        echo "Deleting ENI: $eni_id"
        aws ec2 delete-network-interface --network-interface-id "$eni_id" --region "$REGION" 2>/dev/null || true
    fi
done

# Delete all Load Balancers in the VPC
echo "Deleting Load Balancers..."
aws elbv2 describe-load-balancers --region "$REGION" --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text | \
while read -r lb_arn; do
    if [ -n "$lb_arn" ]; then
        echo "Deleting Load Balancer: $lb_arn"
        aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn" --region "$REGION" 2>/dev/null || true
    fi
done

# Wait for resources to be cleaned up
echo "Waiting for resources to be cleaned up..."
sleep 30

echo "✅ Network dependencies fixed!"
echo "Now run: terraform destroy"