#!/bin/bash

# Simple Cleanup Script - Minimal dependencies
# Use this if the main cleanup script fails due to missing tools

set -e

CLUSTER_NAME=""
REGION="us-east-1"

echo "🧹 Simple EKS Cleanup Script"
echo "=========================="

# Get cluster name
if [ -z "$CLUSTER_NAME" ]; then
    if [ -f "terraform.tfstate" ]; then
        CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")
    fi
    
    if [ -z "$CLUSTER_NAME" ]; then
        read -p "Enter EKS cluster name: " CLUSTER_NAME
    fi
fi

echo "Using cluster: $CLUSTER_NAME"

# Update kubeconfig
echo "Updating kubeconfig..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME" 2>/dev/null || echo "Failed to update kubeconfig"

# Basic cleanup commands
echo "Cleaning up basic resources..."

# Delete common LoadBalancer services
kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer --ignore-not-found=true 2>/dev/null || true

# Delete retail store namespaces
kubectl delete namespace retail-store-dev --ignore-not-found=true 2>/dev/null || true
kubectl delete namespace retail-store-staging --ignore-not-found=true 2>/dev/null || true  
kubectl delete namespace retail-store-prod --ignore-not-found=true 2>/dev/null || true

# Delete AWS Load Balancer Controller
kubectl delete deployment aws-load-balancer-controller -n kube-system --ignore-not-found=true 2>/dev/null || true

# Delete all PVCs
kubectl delete pvc --all --all-namespaces --ignore-not-found=true 2>/dev/null || true

# Wait for cleanup
echo "Waiting 60 seconds for resources to be cleaned up..."
sleep 60

# Clean up AWS resources
echo "Cleaning up AWS Load Balancers..."
aws elbv2 describe-load-balancers --region "$REGION" --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-')].LoadBalancerArn" --output text 2>/dev/null | \
while read -r alb_arn; do
    if [ -n "$alb_arn" ] && [ "$alb_arn" != "None" ]; then
        echo "Deleting ALB: $alb_arn"
        aws elbv2 delete-load-balancer --load-balancer-arn "$alb_arn" --region "$REGION" 2>/dev/null || true
    fi
done

echo "✅ Simple cleanup completed!"
echo "Now run: terraform destroy"