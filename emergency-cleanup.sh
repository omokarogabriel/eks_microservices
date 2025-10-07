#!/bin/bash

# Emergency Cleanup - One-liner commands
REGION="us-east-1"
VPC_ID="vpc-0fba9a19dba37178e"  # Replace with your VPC ID

echo "🚨 Emergency Cleanup"

# Release ALL Elastic IPs
aws ec2 describe-addresses --region $REGION --query 'Addresses[].AllocationId' --output text | xargs -n1 -I {} aws ec2 release-address --allocation-id {} --region $REGION 2>/dev/null || true

# Delete ALL NAT Gateways
aws ec2 describe-nat-gateways --region $REGION --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways[].NatGatewayId' --output text | xargs -n1 -I {} aws ec2 delete-nat-gateway --nat-gateway-id {} --region $REGION 2>/dev/null || true

# Delete ALL Load Balancers
aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text | xargs -n1 -I {} aws elbv2 delete-load-balancer --load-balancer-arn {} --region $REGION 2>/dev/null || true

# Delete ALL Network Interfaces in VPC
aws ec2 describe-network-interfaces --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text | xargs -n1 -I {} aws ec2 delete-network-interface --network-interface-id {} --region $REGION 2>/dev/null || true

echo "✅ Emergency cleanup done. Wait 60 seconds then run terraform destroy"