#!/bin/bash

# Cleanup Dependencies Script
# Removes all resources that could prevent Terraform destroy
# Run this before terraform destroy to avoid dependency issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME=""
REGION="us-east-1"
NAMESPACE="retail-store-dev"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get cluster name from terraform output
get_cluster_name() {
    if [ -z "$CLUSTER_NAME" ]; then
        if [ -f "terraform.tfstate" ]; then
            CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")
        fi
        
        if [ -z "$CLUSTER_NAME" ]; then
            print_warning "Cluster name not found in terraform output. Please provide it manually:"
            read -p "Enter EKS cluster name: " CLUSTER_NAME
        fi
    fi
    
    if [ -z "$CLUSTER_NAME" ]; then
        print_error "Cluster name is required"
        exit 1
    fi
    
    print_status "Using cluster: $CLUSTER_NAME"
}

# Function to update kubeconfig
update_kubeconfig() {
    print_status "Updating kubeconfig for cluster: $CLUSTER_NAME"
    if ! aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME" 2>/dev/null; then
        print_warning "Failed to update kubeconfig. Cluster might not exist or you lack permissions."
        return 1
    fi
    return 0
}

# Function to check if cluster exists and is accessible
check_cluster_access() {
    print_status "Checking cluster access..."
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_warning "Cannot access cluster. It might already be deleted or you lack permissions."
        return 1
    fi
    return 0
}

# Function to remove Helm releases
cleanup_helm_releases() {
    print_status "Cleaning up Helm releases..."
    
    if ! command_exists helm; then
        print_warning "Helm not found, skipping Helm cleanup"
        return
    fi
    
    # Get all releases in the namespace
    local releases=$(helm list -n "$NAMESPACE" -q 2>/dev/null || echo "")
    
    if [ -n "$releases" ]; then
        print_status "Found Helm releases: $releases"
        for release in $releases; do
            print_status "Uninstalling Helm release: $release"
            helm uninstall "$release" -n "$NAMESPACE" --wait --timeout=300s || print_warning "Failed to uninstall $release"
        done
    else
        print_status "No Helm releases found in namespace $NAMESPACE"
    fi
    
    # Check other namespaces for retail-store releases
    local all_releases=$(helm list -A -q 2>/dev/null | grep -E "(cart|catalog|order|checkout|ui)" || echo "")
    if [ -n "$all_releases" ]; then
        print_status "Found retail-store releases in other namespaces"
        helm list -A | grep -E "(cart|catalog|order|checkout|ui)" | while read -r line; do
            local release_name=$(echo "$line" | awk '{print $1}')
            local release_namespace=$(echo "$line" | awk '{print $2}')
            print_status "Uninstalling $release_name from namespace $release_namespace"
            helm uninstall "$release_name" -n "$release_namespace" --wait --timeout=300s || print_warning "Failed to uninstall $release_name"
        done
    fi
}

# Function to remove AWS Load Balancer Controller
cleanup_alb_controller() {
    print_status "Cleaning up AWS Load Balancer Controller..."
    
    # Remove ALB controller deployment
    kubectl delete deployment aws-load-balancer-controller -n kube-system --ignore-not-found=true
    
    # Remove ALB controller service account
    kubectl delete serviceaccount aws-load-balancer-controller -n kube-system --ignore-not-found=true
    
    # Remove ALB controller cluster role and binding
    kubectl delete clusterrole aws-load-balancer-controller --ignore-not-found=true
    kubectl delete clusterrolebinding aws-load-balancer-controller --ignore-not-found=true
    
    # Remove webhook configurations
    kubectl delete validatingwebhookconfiguration aws-load-balancer-webhook --ignore-not-found=true
    kubectl delete mutatingwebhookconfiguration aws-load-balancer-webhook --ignore-not-found=true
}

# Function to remove all LoadBalancers and clean up AWS resources
cleanup_load_balancers() {
    print_status "Cleaning up LoadBalancer services..."
    
    # Delete all LoadBalancer services
    kubectl get svc --all-namespaces -o json | jq -r '.items[] | select(.spec.type=="LoadBalancer") | "\(.metadata.namespace) \(.metadata.name)"' | while read -r namespace name; do
        if [ -n "$namespace" ] && [ -n "$name" ]; then
            print_status "Deleting LoadBalancer service: $name in namespace $namespace"
            kubectl delete svc "$name" -n "$namespace" --ignore-not-found=true
        fi
    done
    
    # Wait for LoadBalancers to be cleaned up
    print_status "Waiting for LoadBalancers to be cleaned up..."
    sleep 30
    
    # Clean up orphaned ALBs
    print_status "Checking for orphaned Application Load Balancers..."
    local albs=$(aws elbv2 describe-load-balancers --region "$REGION" --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-') || contains(Tags[?Key=='kubernetes.io/cluster/$CLUSTER_NAME'].Value, 'owned')].LoadBalancerArn" --output text 2>/dev/null || echo "")
    
    if [ -n "$albs" ]; then
        for alb_arn in $albs; do
            print_status "Deleting orphaned ALB: $alb_arn"
            aws elbv2 delete-load-balancer --load-balancer-arn "$alb_arn" --region "$REGION" 2>/dev/null || print_warning "Failed to delete ALB: $alb_arn"
        done
    fi
}

# Function to remove persistent volumes
cleanup_persistent_volumes() {
    print_status "Cleaning up Persistent Volumes..."
    
    # Delete all PVCs
    kubectl get pvc --all-namespaces -o json | jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | while read -r namespace name; do
        if [ -n "$namespace" ] && [ -n "$name" ]; then
            print_status "Deleting PVC: $name in namespace $namespace"
            kubectl delete pvc "$name" -n "$namespace" --ignore-not-found=true
        fi
    done
    
    # Wait for PVCs to be deleted
    sleep 10
    
    # Force delete any remaining PVs
    kubectl get pv -o json | jq -r '.items[] | select(.spec.claimRef.name != null) | .metadata.name' | while read -r pv_name; do
        if [ -n "$pv_name" ]; then
            print_status "Force deleting PV: $pv_name"
            kubectl patch pv "$pv_name" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
            kubectl delete pv "$pv_name" --ignore-not-found=true
        fi
    done
}

# Function to remove namespaces
cleanup_namespaces() {
    print_status "Cleaning up application namespaces..."
    
    # List of namespaces to clean up
    local namespaces=("$NAMESPACE" "retail-store-staging" "retail-store-prod" "aws-load-balancer-controller")
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" >/dev/null 2>&1; then
            print_status "Deleting namespace: $ns"
            kubectl delete namespace "$ns" --ignore-not-found=true &
        fi
    done
    
    # Wait for namespace deletions to complete
    wait
    
    # Force delete stuck namespaces
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" >/dev/null 2>&1; then
            print_status "Force deleting stuck namespace: $ns"
            kubectl get namespace "$ns" -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - 2>/dev/null || true
        fi
    done
}

# Function to clean up security groups
cleanup_security_groups() {
    print_status "Cleaning up orphaned security groups..."
    
    # Get VPC ID from cluster
    local vpc_id=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null || echo "")
    
    if [ -n "$vpc_id" ] && [ "$vpc_id" != "None" ]; then
        # Find security groups with cluster tags
        local sg_ids=$(aws ec2 describe-security-groups --region "$REGION" --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:kubernetes.io/cluster/$CLUSTER_NAME,Values=owned" --query 'SecurityGroups[].GroupId' --output text 2>/dev/null || echo "")
        
        if [ -n "$sg_ids" ]; then
            for sg_id in $sg_ids; do
                print_status "Attempting to delete security group: $sg_id"
                # Remove all rules first
                aws ec2 describe-security-groups --group-ids "$sg_id" --region "$REGION" --query 'SecurityGroups[0].IpPermissions' --output json 2>/dev/null | \
                jq -r '.[] | @base64' | while read -r rule; do
                    echo "$rule" | base64 -d | aws ec2 revoke-security-group-ingress --group-id "$sg_id" --region "$REGION" --ip-permissions file:///dev/stdin 2>/dev/null || true
                done
                
                aws ec2 describe-security-groups --group-ids "$sg_id" --region "$REGION" --query 'SecurityGroups[0].IpPermissionsEgress' --output json 2>/dev/null | \
                jq -r '.[] | @base64' | while read -r rule; do
                    echo "$rule" | base64 -d | aws ec2 revoke-security-group-egress --group-id "$sg_id" --region "$REGION" --ip-permissions file:///dev/stdin 2>/dev/null || true
                done
                
                # Delete the security group
                aws ec2 delete-security-group --group-id "$sg_id" --region "$REGION" 2>/dev/null || print_warning "Could not delete security group: $sg_id"
            done
        fi
    fi
}

# Function to clean up EBS volumes
cleanup_ebs_volumes() {
    print_status "Cleaning up orphaned EBS volumes..."
    
    # Find volumes tagged with cluster name
    local volume_ids=$(aws ec2 describe-volumes --region "$REGION" --filters "Name=tag:kubernetes.io/cluster/$CLUSTER_NAME,Values=owned" "Name=state,Values=available" --query 'Volumes[].VolumeId' --output text 2>/dev/null || echo "")
    
    if [ -n "$volume_ids" ]; then
        for volume_id in $volume_ids; do
            print_status "Deleting orphaned EBS volume: $volume_id"
            aws ec2 delete-volume --volume-id "$volume_id" --region "$REGION" 2>/dev/null || print_warning "Could not delete volume: $volume_id"
        done
    fi
}

# Function to remove finalizers from stuck resources
remove_finalizers() {
    print_status "Removing finalizers from stuck resources..."
    
    # Remove finalizers from nodes
    kubectl get nodes -o json | jq -r '.items[].metadata.name' | while read -r node; do
        if [ -n "$node" ]; then
            kubectl patch node "$node" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
        fi
    done
    
    # Remove finalizers from persistent volumes
    kubectl get pv -o json | jq -r '.items[].metadata.name' | while read -r pv; do
        if [ -n "$pv" ]; then
            kubectl patch pv "$pv" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
        fi
    done
}

# Main cleanup function
main() {
    print_status "Starting dependency cleanup for EKS cluster destruction..."
    
    # Check prerequisites
    if ! command_exists aws; then
        print_error "AWS CLI not found. Please install it first."
        exit 1
    fi
    
    if ! command_exists kubectl; then
        print_error "kubectl not found. Please install it first."
        exit 1
    fi
    
    if ! command_exists jq; then
        print_error "jq not found. Please install it first."
        exit 1
    fi
    
    # Get cluster name
    get_cluster_name
    
    # Update kubeconfig and check access
    if update_kubeconfig && check_cluster_access; then
        print_status "Cluster is accessible, proceeding with cleanup..."
        
        # Cleanup in order
        cleanup_helm_releases
        cleanup_alb_controller
        cleanup_load_balancers
        cleanup_persistent_volumes
        remove_finalizers
        cleanup_namespaces
        
        # Wait a bit for AWS resources to be cleaned up
        print_status "Waiting for AWS resources to be cleaned up..."
        sleep 60
        
        cleanup_security_groups
        cleanup_ebs_volumes
        
        print_status "Kubernetes resource cleanup completed!"
    else
        print_warning "Cluster not accessible, skipping Kubernetes cleanup"
        print_status "Proceeding with AWS resource cleanup only..."
        
        cleanup_security_groups
        cleanup_ebs_volumes
    fi
    
    print_status "Dependency cleanup completed!"
    print_status "You can now run 'terraform destroy' safely."
    
    # Final recommendations
    echo ""
    print_status "Recommended next steps:"
    echo "1. Run: terraform destroy"
    echo "2. If destroy fails, wait 5 minutes and retry"
    echo "3. Check AWS console for any remaining resources"
    echo "4. Manually delete any remaining Load Balancers or Security Groups if needed"
}

# Run main function
main "$@"