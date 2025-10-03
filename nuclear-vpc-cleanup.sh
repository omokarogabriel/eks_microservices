#!/bin/bash

# Nuclear VPC Cleanup - Removes ALL dependencies
set -e

REGION="us-east-1"
VPC_ID="vpc-011fd6014a33a3da2"

echo "☢️  NUCLEAR VPC CLEANUP - Removing ALL dependencies"
echo "VPC: $VPC_ID"
echo "This will remove EVERYTHING in the VPC!"

# Function to check if resource exists
resource_exists() {
    local check_command="$1"
    eval "$check_command" >/dev/null 2>&1
}

# 1. Delete ALL instances in VPC
echo "1. Terminating ALL instances..."
aws ec2 describe-instances --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running,stopped,stopping,pending" --query 'Reservations[].Instances[].InstanceId' --output text | \
tr '\t' '\n' | while read -r instance_id; do
    if [ -n "$instance_id" ] && [ "$instance_id" != "None" ]; then
        echo "Terminating: $instance_id"
        aws ec2 terminate-instances --instance-ids "$instance_id" --region "$REGION" 2>/dev/null || true
    fi
done

# 2. Delete ALL Load Balancers
echo "2. Deleting ALL Load Balancers..."
# ALBs/NLBs
aws elbv2 describe-load-balancers --region "$REGION" --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text | \
tr '\t' '\n' | while read -r lb_arn; do
    if [ -n "$lb_arn" ] && [ "$lb_arn" != "None" ]; then
        echo "Deleting ALB/NLB: $lb_arn"
        aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn" --region "$REGION" 2>/dev/null || true
    fi
done

# Classic Load Balancers
aws elb describe-load-balancers --region "$REGION" --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" --output text | \
tr '\t' '\n' | while read -r lb_name; do
    if [ -n "$lb_name" ] && [ "$lb_name" != "None" ]; then
        echo "Deleting Classic LB: $lb_name"
        aws elb delete-load-balancer --load-balancer-name "$lb_name" --region "$REGION" 2>/dev/null || true
    fi
done

# 3. Release ALL Elastic IPs
echo "3. Releasing ALL Elastic IPs..."
aws ec2 describe-addresses --region "$REGION" --query 'Addresses[].AllocationId' --output text | \
tr '\t' '\n' | while read -r allocation_id; do
    if [ -n "$allocation_id" ] && [ "$allocation_id" != "None" ]; then
        echo "Releasing EIP: $allocation_id"
        aws ec2 release-address --allocation-id "$allocation_id" --region "$REGION" 2>/dev/null || true
    fi
done

# 4. Delete ALL NAT Gateways
echo "4. Deleting ALL NAT Gateways..."
aws ec2 describe-nat-gateways --region "$REGION" --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways[].NatGatewayId' --output text | \
tr '\t' '\n' | while read -r nat_id; do
    if [ -n "$nat_id" ] && [ "$nat_id" != "None" ]; then
        echo "Deleting NAT: $nat_id"
        aws ec2 delete-nat-gateway --nat-gateway-id "$nat_id" --region "$REGION" 2>/dev/null || true
    fi
done

# 5. Delete ALL VPC Endpoints
echo "5. Deleting ALL VPC Endpoints..."
aws ec2 describe-vpc-endpoints --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'VpcEndpoints[].VpcEndpointId' --output text | \
tr '\t' '\n' | while read -r endpoint_id; do
    if [ -n "$endpoint_id" ] && [ "$endpoint_id" != "None" ]; then
        echo "Deleting VPC Endpoint: $endpoint_id"
        aws ec2 delete-vpc-endpoint --vpc-endpoint-id "$endpoint_id" --region "$REGION" 2>/dev/null || true
    fi
done

# 6. Delete ALL VPC Peering Connections
echo "6. Deleting VPC Peering Connections..."
aws ec2 describe-vpc-peering-connections --region "$REGION" --filters "Name=requester-vpc-info.vpc-id,Values=$VPC_ID" --query 'VpcPeeringConnections[].VpcPeeringConnectionId' --output text | \
tr '\t' '\n' | while read -r peer_id; do
    if [ -n "$peer_id" ] && [ "$peer_id" != "None" ]; then
        echo "Deleting VPC Peering: $peer_id"
        aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id "$peer_id" --region "$REGION" 2>/dev/null || true
    fi
done

# 7. Delete ALL Customer Gateways
echo "7. Deleting Customer Gateways..."
aws ec2 describe-customer-gateways --region "$REGION" --query 'CustomerGateways[].CustomerGatewayId' --output text | \
tr '\t' '\n' | while read -r cgw_id; do
    if [ -n "$cgw_id" ] && [ "$cgw_id" != "None" ]; then
        echo "Deleting Customer Gateway: $cgw_id"
        aws ec2 delete-customer-gateway --customer-gateway-id "$cgw_id" --region "$REGION" 2>/dev/null || true
    fi
done

# 8. Delete ALL VPN Connections
echo "8. Deleting VPN Connections..."
aws ec2 describe-vpn-connections --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'VpnConnections[].VpnConnectionId' --output text | \
tr '\t' '\n' | while read -r vpn_id; do
    if [ -n "$vpn_id" ] && [ "$vpn_id" != "None" ]; then
        echo "Deleting VPN: $vpn_id"
        aws ec2 delete-vpn-connection --vpn-connection-id "$vpn_id" --region "$REGION" 2>/dev/null || true
    fi
done

# Wait for resources to be deleted
echo "Waiting 60 seconds for resources to be deleted..."
sleep 60

# 9. Force delete ALL Network Interfaces
echo "9. Force deleting ALL Network Interfaces..."
aws ec2 describe-network-interfaces --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text | \
tr '\t' '\n' | while read -r eni_id; do
    if [ -n "$eni_id" ] && [ "$eni_id" != "None" ]; then
        echo "Processing ENI: $eni_id"
        
        # Force detach
        attachment_id=$(aws ec2 describe-network-interfaces --network-interface-ids "$eni_id" --region "$REGION" --query 'NetworkInterfaces[0].Attachment.AttachmentId' --output text 2>/dev/null || echo "")
        if [ -n "$attachment_id" ] && [ "$attachment_id" != "None" ] && [ "$attachment_id" != "null" ]; then
            echo "Force detaching: $eni_id"
            aws ec2 detach-network-interface --attachment-id "$attachment_id" --region "$REGION" --force 2>/dev/null || true
            sleep 2
        fi
        
        # Force delete
        echo "Force deleting: $eni_id"
        aws ec2 delete-network-interface --network-interface-id "$eni_id" --region "$REGION" 2>/dev/null || true
    fi
done

# 10. Delete ALL Security Groups (except default)
echo "10. Deleting ALL Security Groups..."
aws ec2 describe-security-groups --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text | \
tr '\t' '\n' | while read -r sg_id; do
    if [ -n "$sg_id" ] && [ "$sg_id" != "None" ]; then
        echo "Processing SG: $sg_id"
        
        # Remove all ingress rules
        aws ec2 describe-security-groups --group-ids "$sg_id" --region "$REGION" --query 'SecurityGroups[0].IpPermissions' --output json 2>/dev/null | \
        jq -c '.[]?' 2>/dev/null | while read -r rule; do
            if [ -n "$rule" ] && [ "$rule" != "null" ]; then
                echo "$rule" | aws ec2 revoke-security-group-ingress --group-id "$sg_id" --region "$REGION" --ip-permissions file:///dev/stdin 2>/dev/null || true
            fi
        done
        
        # Remove all egress rules
        aws ec2 describe-security-groups --group-ids "$sg_id" --region "$REGION" --query 'SecurityGroups[0].IpPermissionsEgress' --output json 2>/dev/null | \
        jq -c '.[]?' 2>/dev/null | while read -r rule; do
            if [ -n "$rule" ] && [ "$rule" != "null" ]; then
                echo "$rule" | aws ec2 revoke-security-group-egress --group-id "$sg_id" --region "$REGION" --ip-permissions file:///dev/stdin 2>/dev/null || true
            fi
        done
        
        # Delete security group
        echo "Deleting SG: $sg_id"
        aws ec2 delete-security-group --group-id "$sg_id" --region "$REGION" 2>/dev/null || true
    fi
done

# 11. Delete ALL Route Tables (except main)
echo "11. Deleting Route Tables..."
aws ec2 describe-route-tables --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text | \
tr '\t' '\n' | while read -r rt_id; do
    if [ -n "$rt_id" ] && [ "$rt_id" != "None" ]; then
        echo "Deleting Route Table: $rt_id"
        
        # Disassociate all subnets
        aws ec2 describe-route-tables --route-table-ids "$rt_id" --region "$REGION" --query 'RouteTables[0].Associations[?Main!=`true`].RouteTableAssociationId' --output text | \
        tr '\t' '\n' | while read -r assoc_id; do
            if [ -n "$assoc_id" ] && [ "$assoc_id" != "None" ]; then
                echo "Disassociating: $assoc_id"
                aws ec2 disassociate-route-table --association-id "$assoc_id" --region "$REGION" 2>/dev/null || true
            fi
        done
        
        # Delete route table
        aws ec2 delete-route-table --route-table-id "$rt_id" --region "$REGION" 2>/dev/null || true
    fi
done

# 12. Delete ALL Subnets
echo "12. Deleting ALL Subnets..."
aws ec2 describe-subnets --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text | \
tr '\t' '\n' | while read -r subnet_id; do
    if [ -n "$subnet_id" ] && [ "$subnet_id" != "None" ]; then
        echo "Deleting Subnet: $subnet_id"
        aws ec2 delete-subnet --subnet-id "$subnet_id" --region "$REGION" 2>/dev/null || true
    fi
done

# 13. Delete ALL Network ACLs (except default)
echo "13. Deleting Network ACLs..."
aws ec2 describe-network-acls --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkAcls[?IsDefault!=`true`].NetworkAclId' --output text | \
tr '\t' '\n' | while read -r acl_id; do
    if [ -n "$acl_id" ] && [ "$acl_id" != "None" ]; then
        echo "Deleting Network ACL: $acl_id"
        aws ec2 delete-network-acl --network-acl-id "$acl_id" --region "$REGION" 2>/dev/null || true
    fi
done

# 14. Detach Internet Gateway
echo "14. Detaching Internet Gateway..."
aws ec2 describe-internet-gateways --region "$REGION" --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[].InternetGatewayId' --output text | \
tr '\t' '\n' | while read -r igw_id; do
    if [ -n "$igw_id" ] && [ "$igw_id" != "None" ]; then
        echo "Detaching IGW: $igw_id"
        aws ec2 detach-internet-gateway --internet-gateway-id "$igw_id" --vpc-id "$VPC_ID" --region "$REGION" 2>/dev/null || true
        echo "Deleting IGW: $igw_id"
        aws ec2 delete-internet-gateway --internet-gateway-id "$igw_id" --region "$REGION" 2>/dev/null || true
    fi
done

# Final wait
echo "Final wait (30 seconds)..."
sleep 30

echo "☢️  Nuclear cleanup completed!"
echo "Now run: terraform destroy"