#!/bin/bash

# Comprehensive VPC Dependencies Fix
# Automatically detects and fixes all VPC-related dependency issues

set -e

REGION="us-east-1"

echo "🔧 Comprehensive VPC Dependencies Fix"

# Get VPC and IGW from terraform state
VPC_ID=$(terraform show -json 2>/dev/null | jq -r '.values.root_module.resources[] | select(.type=="aws_vpc") | .values.id' 2>/dev/null || echo "")
IGW_ID=$(terraform show -json 2>/dev/null | jq -r '.values.root_module.resources[] | select(.type=="aws_internet_gateway") | .values.id' 2>/dev/null || echo "")

if [ -z "$VPC_ID" ]; then
    echo "Could not find VPC ID from terraform state. Please provide it:"
    read -p "Enter VPC ID: " VPC_ID
fi

if [ -z "$IGW_ID" ]; then
    echo "Could not find IGW ID from terraform state. Please provide it:"
    read -p "Enter Internet Gateway ID: " IGW_ID
fi

echo "VPC ID: $VPC_ID"
echo "IGW ID: $IGW_ID"

# Function to wait for resource deletion
wait_for_deletion() {
    local resource_type="$1"
    local check_command="$2"
    echo "Waiting for $resource_type to be deleted..."
    
    for i in {1..12}; do
        if ! eval "$check_command" >/dev/null 2>&1; then
            echo "$resource_type deleted successfully"
            return 0
        fi
        echo "Still waiting for $resource_type... ($i/12)"
        sleep 10
    done
    echo "Warning: $resource_type may still exist"
}

# 1. Release all Elastic IPs
echo "Step 1: Releasing Elastic IPs..."
aws ec2 describe-addresses --region "$REGION" --filters "Name=domain,Values=vpc" --query 'Addresses[].AllocationId' --output text | \
tr '\t' '\n' | while read -r allocation_id; do
    if [ -n "$allocation_id" ] && [ "$allocation_id" != "None" ]; then
        echo "Releasing EIP: $allocation_id"
        aws ec2 release-address --allocation-id "$allocation_id" --region "$REGION" 2>/dev/null || echo "Failed to release $allocation_id"
    fi
done

# 2. Delete NAT Gateways
echo "Step 2: Deleting NAT Gateways..."
aws ec2 describe-nat-gateways --region "$REGION" --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" --query 'NatGateways[].NatGatewayId' --output text | \
tr '\t' '\n' | while read -r nat_id; do
    if [ -n "$nat_id" ] && [ "$nat_id" != "None" ]; then
        echo "Deleting NAT Gateway: $nat_id"
        aws ec2 delete-nat-gateway --nat-gateway-id "$nat_id" --region "$REGION" 2>/dev/null || echo "Failed to delete $nat_id"
    fi
done

wait_for_deletion "NAT Gateways" "aws ec2 describe-nat-gateways --region $REGION --filter Name=vpc-id,Values=$VPC_ID Name=state,Values=available --query 'NatGateways[0]'"

# 3. Delete Load Balancers
echo "Step 3: Deleting Load Balancers..."
aws elbv2 describe-load-balancers --region "$REGION" --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text | \
tr '\t' '\n' | while read -r lb_arn; do
    if [ -n "$lb_arn" ] && [ "$lb_arn" != "None" ]; then
        echo "Deleting Load Balancer: $lb_arn"
        aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn" --region "$REGION" 2>/dev/null || echo "Failed to delete $lb_arn"
    fi
done

# 4. Delete VPC Endpoints
echo "Step 4: Deleting VPC Endpoints..."
aws ec2 describe-vpc-endpoints --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'VpcEndpoints[].VpcEndpointId' --output text | \
tr '\t' '\n' | while read -r endpoint_id; do
    if [ -n "$endpoint_id" ] && [ "$endpoint_id" != "None" ]; then
        echo "Deleting VPC Endpoint: $endpoint_id"
        aws ec2 delete-vpc-endpoint --vpc-endpoint-id "$endpoint_id" --region "$REGION" 2>/dev/null || echo "Failed to delete $endpoint_id"
    fi
done

# 5. Detach and delete Network Interfaces
echo "Step 5: Deleting Network Interfaces..."
aws ec2 describe-network-interfaces --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text | \
tr '\t' '\n' | while read -r eni_id; do
    if [ -n "$eni_id" ] && [ "$eni_id" != "None" ]; then
        echo "Processing ENI: $eni_id"
        
        # Detach if attached
        attachment_id=$(aws ec2 describe-network-interfaces --network-interface-ids "$eni_id" --region "$REGION" --query 'NetworkInterfaces[0].Attachment.AttachmentId' --output text 2>/dev/null || echo "")
        if [ -n "$attachment_id" ] && [ "$attachment_id" != "None" ] && [ "$attachment_id" != "null" ]; then
            echo "Detaching ENI: $eni_id"
            aws ec2 detach-network-interface --attachment-id "$attachment_id" --region "$REGION" --force 2>/dev/null || echo "Failed to detach $eni_id"
            sleep 5
        fi
        
        # Delete ENI
        echo "Deleting ENI: $eni_id"
        aws ec2 delete-network-interface --network-interface-id "$eni_id" --region "$REGION" 2>/dev/null || echo "Failed to delete $eni_id"
    fi
done

# 6. Delete Security Groups (except default)
echo "Step 6: Deleting Security Groups..."
aws ec2 describe-security-groups --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text | \
tr '\t' '\n' | while read -r sg_id; do
    if [ -n "$sg_id" ] && [ "$sg_id" != "None" ]; then
        echo "Deleting Security Group: $sg_id"
        
        # Remove all rules first
        aws ec2 describe-security-groups --group-ids "$sg_id" --region "$REGION" --query 'SecurityGroups[0].IpPermissions' --output json 2>/dev/null | \
        jq -c '.[]?' 2>/dev/null | while read -r rule; do
            if [ -n "$rule" ] && [ "$rule" != "null" ]; then
                echo "$rule" | aws ec2 revoke-security-group-ingress --group-id "$sg_id" --region "$REGION" --ip-permissions file:///dev/stdin 2>/dev/null || true
            fi
        done
        
        aws ec2 describe-security-groups --group-ids "$sg_id" --region "$REGION" --query 'SecurityGroups[0].IpPermissionsEgress' --output json 2>/dev/null | \
        jq -c '.[]?' 2>/dev/null | while read -r rule; do
            if [ -n "$rule" ] && [ "$rule" != "null" ]; then
                echo "$rule" | aws ec2 revoke-security-group-egress --group-id "$sg_id" --region "$REGION" --ip-permissions file:///dev/stdin 2>/dev/null || true
            fi
        done
        
        # Delete security group
        aws ec2 delete-security-group --group-id "$sg_id" --region "$REGION" 2>/dev/null || echo "Failed to delete $sg_id"
    fi
done

# Wait for everything to be cleaned up
echo "Waiting for final cleanup..."
sleep 30

echo "✅ VPC dependencies cleanup completed!"
echo ""
echo "Now you can run:"
echo "terraform destroy"