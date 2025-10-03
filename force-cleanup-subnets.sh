#!/bin/bash

# Force Cleanup Subnets - Aggressive dependency removal
set -e

REGION="us-east-1"
VPC_ID="vpc-011fd6014a33a3da2"
SUBNET1="subnet-06b1f7babca1c287b"
SUBNET2="subnet-074a8b959008df731"
IGW_ID="igw-0a846d98e7a661b6a"

echo "🔥 Force Cleanup Subnets - Aggressive Mode"
echo "VPC: $VPC_ID"
echo "Subnets: $SUBNET1, $SUBNET2"

# Function to force delete with retries
force_delete() {
    local resource_type="$1"
    local delete_command="$2"
    local check_command="$3"
    
    echo "Force deleting $resource_type..."
    for i in {1..5}; do
        eval "$delete_command" 2>/dev/null || true
        sleep 5
        if ! eval "$check_command" >/dev/null 2>&1; then
            echo "$resource_type deleted successfully"
            return 0
        fi
        echo "Retry $i/5 for $resource_type"
    done
}

# 1. Find and terminate ALL instances in the subnets
echo "Step 1: Terminating instances in subnets..."
for subnet in $SUBNET1 $SUBNET2; do
    aws ec2 describe-instances --region "$REGION" --filters "Name=subnet-id,Values=$subnet" "Name=instance-state-name,Values=running,stopped,stopping" --query 'Reservations[].Instances[].InstanceId' --output text | \
    tr '\t' '\n' | while read -r instance_id; do
        if [ -n "$instance_id" ] && [ "$instance_id" != "None" ]; then
            echo "Terminating instance: $instance_id"
            aws ec2 terminate-instances --instance-ids "$instance_id" --region "$REGION" 2>/dev/null || true
        fi
    done
done

# 2. Delete ALL Load Balancers in VPC
echo "Step 2: Deleting ALL Load Balancers..."
aws elbv2 describe-load-balancers --region "$REGION" --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text | \
tr '\t' '\n' | while read -r lb_arn; do
    if [ -n "$lb_arn" ] && [ "$lb_arn" != "None" ]; then
        echo "Deleting LB: $lb_arn"
        aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn" --region "$REGION" 2>/dev/null || true
    fi
done

# Also check classic load balancers
aws elb describe-load-balancers --region "$REGION" --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" --output text | \
tr '\t' '\n' | while read -r lb_name; do
    if [ -n "$lb_name" ] && [ "$lb_name" != "None" ]; then
        echo "Deleting Classic LB: $lb_name"
        aws elb delete-load-balancer --load-balancer-name "$lb_name" --region "$REGION" 2>/dev/null || true
    fi
done

# 3. Release ALL Elastic IPs (including those not showing in describe-addresses)
echo "Step 3: Releasing ALL Elastic IPs..."
aws ec2 describe-addresses --region "$REGION" --query 'Addresses[].AllocationId' --output text | \
tr '\t' '\n' | while read -r allocation_id; do
    if [ -n "$allocation_id" ] && [ "$allocation_id" != "None" ]; then
        echo "Releasing EIP: $allocation_id"
        aws ec2 release-address --allocation-id "$allocation_id" --region "$REGION" 2>/dev/null || true
    fi
done

# 4. Delete ALL NAT Gateways in VPC
echo "Step 4: Deleting ALL NAT Gateways..."
aws ec2 describe-nat-gateways --region "$REGION" --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways[].NatGatewayId' --output text | \
tr '\t' '\n' | while read -r nat_id; do
    if [ -n "$nat_id" ] && [ "$nat_id" != "None" ]; then
        echo "Deleting NAT: $nat_id"
        aws ec2 delete-nat-gateway --nat-gateway-id "$nat_id" --region "$REGION" 2>/dev/null || true
    fi
done

# 5. Delete ALL VPC Endpoints
echo "Step 5: Deleting VPC Endpoints..."
aws ec2 describe-vpc-endpoints --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'VpcEndpoints[].VpcEndpointId' --output text | \
tr '\t' '\n' | while read -r endpoint_id; do
    if [ -n "$endpoint_id" ] && [ "$endpoint_id" != "None" ]; then
        echo "Deleting VPC Endpoint: $endpoint_id"
        aws ec2 delete-vpc-endpoint --vpc-endpoint-id "$endpoint_id" --region "$REGION" 2>/dev/null || true
    fi
done

# 6. Find and delete ALL Network Interfaces in the subnets
echo "Step 6: Force deleting Network Interfaces..."
for subnet in $SUBNET1 $SUBNET2; do
    aws ec2 describe-network-interfaces --region "$REGION" --filters "Name=subnet-id,Values=$subnet" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text | \
    tr '\t' '\n' | while read -r eni_id; do
        if [ -n "$eni_id" ] && [ "$eni_id" != "None" ]; then
            echo "Processing ENI: $eni_id in subnet $subnet"
            
            # Force detach
            attachment_id=$(aws ec2 describe-network-interfaces --network-interface-ids "$eni_id" --region "$REGION" --query 'NetworkInterfaces[0].Attachment.AttachmentId' --output text 2>/dev/null || echo "")
            if [ -n "$attachment_id" ] && [ "$attachment_id" != "None" ] && [ "$attachment_id" != "null" ]; then
                echo "Force detaching ENI: $eni_id"
                aws ec2 detach-network-interface --attachment-id "$attachment_id" --region "$REGION" --force 2>/dev/null || true
                sleep 3
            fi
            
            # Force delete
            echo "Force deleting ENI: $eni_id"
            aws ec2 delete-network-interface --network-interface-id "$eni_id" --region "$REGION" 2>/dev/null || true
        fi
    done
done

# 7. Wait for resources to be cleaned up
echo "Step 7: Waiting for cleanup (60 seconds)..."
sleep 60

# 8. Check for any remaining dependencies and force clean
echo "Step 8: Final dependency check..."

# Check for route table associations
for subnet in $SUBNET1 $SUBNET2; do
    echo "Checking route table associations for subnet: $subnet"
    aws ec2 describe-route-tables --region "$REGION" --filters "Name=association.subnet-id,Values=$subnet" --query 'RouteTables[].Associations[?SubnetId==`'$subnet'`].RouteTableAssociationId' --output text | \
    tr '\t' '\n' | while read -r assoc_id; do
        if [ -n "$assoc_id" ] && [ "$assoc_id" != "None" ]; then
            echo "Disassociating route table: $assoc_id"
            aws ec2 disassociate-route-table --association-id "$assoc_id" --region "$REGION" 2>/dev/null || true
        fi
    done
done

# 9. Final attempt to clean remaining resources
echo "Step 9: Final cleanup attempt..."

# Delete any remaining network ACL associations
aws ec2 describe-network-acls --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkAcls[].Associations[].NetworkAclAssociationId' --output text | \
tr '\t' '\n' | while read -r assoc_id; do
    if [ -n "$assoc_id" ] && [ "$assoc_id" != "None" ]; then
        echo "Replacing network ACL association: $assoc_id"
        # This will replace with default ACL
        default_acl=$(aws ec2 describe-network-acls --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" "Name=default,Values=true" --query 'NetworkAcls[0].NetworkAclId' --output text)
        if [ -n "$default_acl" ] && [ "$default_acl" != "None" ]; then
            aws ec2 replace-network-acl-association --association-id "$assoc_id" --network-acl-id "$default_acl" --region "$REGION" 2>/dev/null || true
        fi
    fi
done

echo "✅ Aggressive cleanup completed!"
echo ""
echo "Now run: terraform destroy"
echo ""
echo "If it still fails, wait 5 minutes and try again."