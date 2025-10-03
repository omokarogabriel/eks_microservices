#!/bin/bash

# Check VPC Dependencies
REGION="us-east-1"
VPC_ID="vpc-011fd6014a33a3da2"

echo "🔍 Checking VPC Dependencies for: $VPC_ID"
echo "================================================"

# Check instances
echo "1. EC2 Instances:"
aws ec2 describe-instances --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'Reservations[].Instances[].[InstanceId,State.Name]' --output table 2>/dev/null || echo "None found"

# Check Load Balancers
echo -e "\n2. Load Balancers:"
aws elbv2 describe-load-balancers --region "$REGION" --query "LoadBalancers[?VpcId=='$VPC_ID'].[LoadBalancerName,LoadBalancerArn]" --output table 2>/dev/null || echo "None found"

# Check NAT Gateways
echo -e "\n3. NAT Gateways:"
aws ec2 describe-nat-gateways --region "$REGION" --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways[].[NatGatewayId,State]' --output table 2>/dev/null || echo "None found"

# Check Network Interfaces
echo -e "\n4. Network Interfaces:"
aws ec2 describe-network-interfaces --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[].[NetworkInterfaceId,Status,Description]' --output table 2>/dev/null || echo "None found"

# Check Security Groups
echo -e "\n5. Security Groups:"
aws ec2 describe-security-groups --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].[GroupId,GroupName]' --output table 2>/dev/null || echo "None found"

# Check VPC Endpoints
echo -e "\n6. VPC Endpoints:"
aws ec2 describe-vpc-endpoints --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'VpcEndpoints[].[VpcEndpointId,ServiceName]' --output table 2>/dev/null || echo "None found"

# Check Elastic IPs
echo -e "\n7. Elastic IPs:"
aws ec2 describe-addresses --region "$REGION" --query 'Addresses[].[AllocationId,PublicIp,AssociationId]' --output table 2>/dev/null || echo "None found"

echo -e "\n✅ Dependency check completed!"