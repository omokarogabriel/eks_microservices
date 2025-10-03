# 🧹 Cleanup Guide - Dependency Resolution for Terraform Destroy

This guide provides scripts to resolve all dependency issues that prevent successful `terraform destroy` operations.

## 🚨 Problem

Terraform destroy often fails due to:
- **LoadBalancer services** creating AWS ALBs outside Terraform
- **Persistent Volume Claims** creating EBS volumes
- **Security Groups** with dependencies
- **Helm releases** managing Kubernetes resources
- **AWS Load Balancer Controller** managing AWS resources
- **Finalizers** preventing resource deletion

## 🛠️ Solution Scripts

### 1. Full Cleanup Script (Recommended)
**File**: `cleanup-dependencies.sh`
**Requirements**: `aws`, `kubectl`, `helm`, `jq`

```bash
./cleanup-dependencies.sh
```

**What it does**:
- ✅ Removes all Helm releases (microservices)
- ✅ Deletes AWS Load Balancer Controller
- ✅ Cleans up LoadBalancer services and ALBs
- ✅ Removes Persistent Volumes and Claims
- ✅ Deletes application namespaces
- ✅ Cleans up orphaned Security Groups
- ✅ Removes orphaned EBS volumes
- ✅ Removes finalizers from stuck resources

### 2. Network Dependencies Fix (For VPC/IGW Issues)
**File**: `fix-vpc-dependencies.sh`
**Requirements**: `aws`, `jq`

```bash
./fix-vpc-dependencies.sh
```

**What it does**:
- ✅ Releases all Elastic IPs
- ✅ Deletes NAT Gateways
- ✅ Removes Load Balancers
- ✅ Cleans VPC Endpoints
- ✅ Deletes Network Interfaces
- ✅ Removes Security Groups

### 3. Simple Cleanup Script (Fallback)
**File**: `cleanup-simple.sh`
**Requirements**: `aws`, `kubectl` only

```bash
./cleanup-simple.sh
```

**What it does**:
- ✅ Basic LoadBalancer cleanup
- ✅ Namespace deletion
- ✅ PVC cleanup
- ✅ ALB cleanup

## 📋 Usage Instructions

### Step 1: Choose Your Environment
```bash
# Navigate to your environment
cd environments/dev     # or staging/prod
```

### Step 2: Run Cleanup Script
```bash
# Option A: Full cleanup (recommended)
../../cleanup-dependencies.sh

# Option B: Network dependencies fix (for VPC/IGW errors)
../../fix-vpc-dependencies.sh

# Option C: Simple cleanup (if tools missing)
../../cleanup-simple.sh
```

### Step 3: Verify Cleanup
```bash
# Check no LoadBalancer services remain
kubectl get svc --all-namespaces --field-selector spec.type=LoadBalancer

# Check no PVCs remain
kubectl get pvc --all-namespaces

# Check AWS ALBs are gone
aws elbv2 describe-load-balancers --region us-east-1
```

### Step 4: Run Terraform Destroy
```bash
terraform destroy
```

## 🔧 Manual Cleanup (If Scripts Fail)

### Remove Helm Releases
```bash
# List all releases
helm list -A

# Remove specific releases
helm uninstall cart catalog order checkout ui -n retail-store-dev
```

### Remove LoadBalancer Services
```bash
# Find LoadBalancer services
kubectl get svc --all-namespaces --field-selector spec.type=LoadBalancer

# Delete specific service
kubectl delete svc <service-name> -n <namespace>
```

### Remove AWS Load Balancers
```bash
# List ALBs
aws elbv2 describe-load-balancers --region us-east-1

# Delete specific ALB
aws elbv2 delete-load-balancer --load-balancer-arn <arn>
```

### Remove Persistent Volumes
```bash
# List PVCs
kubectl get pvc --all-namespaces

# Delete PVC
kubectl delete pvc <pvc-name> -n <namespace>

# Force delete PV if stuck
kubectl patch pv <pv-name> -p '{"metadata":{"finalizers":null}}'
kubectl delete pv <pv-name>
```

### Remove Namespaces
```bash
# Delete namespace
kubectl delete namespace retail-store-dev

# Force delete if stuck
kubectl get namespace retail-store-dev -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/retail-store-dev/finalize" -f -
```

## 🚨 Common Issues & Solutions

### Issue: "Internet Gateway has dependencies" / "Subnet has dependencies"
**Solution**: Run the network dependencies fix script
```bash
# Comprehensive fix (recommended)
../../fix-vpc-dependencies.sh

# Or specific fix if you know the IDs
../../fix-network-dependencies.sh
```

### Issue: "LoadBalancer service has dependencies"
**Solution**: 
```bash
kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer
```

### Issue: "Security group has dependencies"
**Solution**: Wait 5-10 minutes after deleting LoadBalancers, then retry

### Issue: "PVC is in use"
**Solution**:
```bash
kubectl delete deployment --all -n <namespace>
kubectl delete pvc --all -n <namespace>
```

### Issue: "Namespace stuck in Terminating"
**Solution**:
```bash
kubectl get namespace <namespace> -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/<namespace>/finalize" -f -
```

### Issue: "EBS volume in use"
**Solution**: Ensure all PVCs are deleted first, then wait 5 minutes

### Issue: "Network vpc-xxx has some mapped public address(es)"
**Solution**: 
```bash
# Release all Elastic IPs and delete NAT Gateways
../../fix-vpc-dependencies.sh
```

## 📊 Cleanup Order (Important!)

1. **Helm Releases** (applications)
2. **LoadBalancer Services** (AWS ALBs)
3. **Persistent Volume Claims** (EBS volumes)
4. **Deployments & Pods**
5. **Namespaces**
6. **AWS Resources** (ALBs, Security Groups, EBS)
7. **Terraform Destroy**

## ⚡ Quick Commands

```bash
# Emergency cleanup (nuclear option)
kubectl delete namespace retail-store-dev retail-store-staging retail-store-prod --ignore-not-found=true
kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer
kubectl delete pvc --all --all-namespaces

# Wait 2 minutes, then
terraform destroy -auto-approve
```

## 🔍 Verification Commands

```bash
# Check cluster status
kubectl cluster-info

# Check no retail-store resources
kubectl get all --all-namespaces | grep retail-store

# Check AWS resources
aws elbv2 describe-load-balancers --region us-east-1 | grep k8s-
aws ec2 describe-volumes --region us-east-1 --filters "Name=state,Values=available"
```

## 📞 Support

If cleanup scripts fail:
1. Run manual cleanup commands above
2. Wait 5-10 minutes between steps
3. Check AWS Console for remaining resources
4. Use `terraform destroy -target=<resource>` for specific resources

**Remember**: Always run cleanup scripts from the environment directory (`environments/dev`, `environments/staging`, or `environments/prod`).