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

### 2. Nuclear VPC Cleanup (For Persistent VPC Issues)
**File**: `nuclear-vpc-cleanup.sh`
**Requirements**: `aws`, `jq`

```bash
./nuclear-vpc-cleanup.sh
```

**What it does**:
- ☢️ Terminates ALL instances in VPC
- ☢️ Deletes ALL Load Balancers (ALB, NLB, Classic)
- ☢️ Releases ALL Elastic IPs
- ☢️ Deletes ALL NAT Gateways
- ☢️ Removes ALL VPC Endpoints
- ☢️ Deletes VPC Peering Connections
- ☢️ Removes Customer Gateways and VPN Connections
- ☢️ Force deletes ALL Network Interfaces
- ☢️ Removes ALL Security Groups
- ☢️ Deletes ALL Route Tables and Subnets
- ☢️ Detaches and deletes Internet Gateway

### 3. VPC Dependency Checker
**File**: `check-vpc-dependencies.sh`
**Requirements**: `aws`

```bash
./check-vpc-dependencies.sh
```

**What it does**:
- 🔍 Lists all EC2 instances in VPC
- 🔍 Shows all Load Balancers
- 🔍 Displays NAT Gateways and their states
- 🔍 Lists Network Interfaces
- 🔍 Shows Security Groups
- 🔍 Displays VPC Endpoints
- 🔍 Lists Elastic IPs

### 4. Network Dependencies Fix (Targeted)
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

### 5. Simple Cleanup Script (Fallback)
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
# Option A: Full cleanup (recommended for normal cases)
../../cleanup-dependencies.sh

# Option B: Check what dependencies exist first
../../check-vpc-dependencies.sh

# Option C: Nuclear cleanup (for persistent VPC dependency issues)
../../nuclear-vpc-cleanup.sh

# Option D: Targeted network fix (for specific VPC/IGW errors)
../../fix-vpc-dependencies.sh

# Option E: Simple cleanup (if advanced tools missing)
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

### Issue: "VPC has dependencies and cannot be deleted"
**Solution**: Run the nuclear VPC cleanup script
```bash
# Check what dependencies exist
../../check-vpc-dependencies.sh

# Nuclear cleanup (removes EVERYTHING)
../../nuclear-vpc-cleanup.sh

# Then retry terraform destroy
terraform destroy
```

### Issue: "Internet Gateway has dependencies" / "Subnet has dependencies"
**Solution**: Run the network dependencies fix script
```bash
# Comprehensive fix (recommended)
../../fix-vpc-dependencies.sh

# Or nuclear option for persistent issues
../../nuclear-vpc-cleanup.sh
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
# Emergency Kubernetes cleanup
kubectl delete namespace retail-store-dev retail-store-staging retail-store-prod --ignore-not-found=true
kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer
kubectl delete pvc --all --all-namespaces

# Emergency AWS cleanup (nuclear option)
../../nuclear-vpc-cleanup.sh

# Wait 2 minutes, then
terraform destroy -auto-approve
```

## 🆘 Escalation Path

**If terraform destroy still fails after nuclear cleanup:**

1. **Manual AWS Console Cleanup**:
   - Go to EC2 Console → Load Balancers → Delete any remaining ALBs
   - Go to VPC Console → Your VPC → Delete remaining resources manually
   - Check CloudFormation for any stacks created by EKS

2. **Targeted Terraform Destroy**:
   ```bash
   # Destroy specific resources first
   terraform destroy -target=module.eks
   terraform destroy -target=module.vpc
   terraform destroy
   ```

3. **State File Cleanup** (Last Resort):
   ```bash
   # Remove problematic resources from state
   terraform state rm 'module.vpc.aws_vpc.this'
   terraform state rm 'module.vpc.aws_internet_gateway.this'
   terraform destroy
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

## 📊 Cleanup Script Comparison

| Script | Use Case | Aggressiveness | Time |
|--------|----------|----------------|------|
| `cleanup-dependencies.sh` | Normal cleanup | Moderate | 2-3 min |
| `fix-vpc-dependencies.sh` | VPC/IGW issues | Targeted | 1-2 min |
| `nuclear-vpc-cleanup.sh` | Persistent issues | Maximum | 3-5 min |
| `cleanup-simple.sh` | Limited tools | Basic | 1 min |
| `check-vpc-dependencies.sh` | Diagnosis | None | 30 sec |

**Remember**: Always run cleanup scripts from the environment directory (`environments/dev`, `environments/staging`, or `environments/prod`).

**⚠️ Warning**: The nuclear cleanup script will remove ALL resources in the VPC. Use only when other methods fail.