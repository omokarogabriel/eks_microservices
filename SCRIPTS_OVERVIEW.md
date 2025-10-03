# 🛠️ Cleanup Scripts Overview

## 📋 Available Scripts

| Script | Purpose | Aggressiveness | Time | Requirements |
|--------|---------|----------------|------|--------------|
| `check-vpc-dependencies.sh` | Diagnose dependencies | None | 30s | `aws` |
| `cleanup-simple.sh` | Basic cleanup | Low | 1min | `aws`, `kubectl` |
| `cleanup-dependencies.sh` | Full cleanup | Medium | 2-3min | `aws`, `kubectl`, `helm`, `jq` |
| `fix-vpc-dependencies.sh` | Network issues | High | 1-2min | `aws`, `jq` |
| `nuclear-vpc-cleanup.sh` | Remove everything | Maximum | 3-5min | `aws`, `jq` |

## 🎯 When to Use Each Script

### `check-vpc-dependencies.sh`
**Use when**: You want to see what's preventing VPC deletion
```bash
../../check-vpc-dependencies.sh
```
**Output**: Lists all resources still attached to VPC

### `cleanup-simple.sh`
**Use when**: Limited tools available or quick basic cleanup
```bash
../../cleanup-simple.sh
```
**What it removes**: LoadBalancer services, namespaces, PVCs, basic ALBs

### `cleanup-dependencies.sh`
**Use when**: Standard cleanup after normal EKS usage
```bash
../../cleanup-dependencies.sh
```
**What it removes**: Helm releases, ALB controller, LoadBalancers, PVCs, namespaces, security groups, EBS volumes

### `fix-vpc-dependencies.sh`
**Use when**: Specific VPC/IGW/subnet dependency errors
```bash
../../fix-vpc-dependencies.sh
```
**What it removes**: Elastic IPs, NAT Gateways, Load Balancers, VPC Endpoints, Network Interfaces, Security Groups

### `nuclear-vpc-cleanup.sh`
**Use when**: All other methods fail and you need to remove EVERYTHING
```bash
../../nuclear-vpc-cleanup.sh
```
**⚠️ WARNING**: This removes ALL resources in the VPC

## 🔄 Recommended Workflow

```bash
# 1. Navigate to environment
cd environments/dev

# 2. Check what exists
../../check-vpc-dependencies.sh

# 3. Try standard cleanup first
../../cleanup-dependencies.sh

# 4. If terraform destroy still fails, check again
../../check-vpc-dependencies.sh

# 5. Use nuclear option if needed
../../nuclear-vpc-cleanup.sh

# 6. Retry terraform destroy
terraform destroy
```

## 🚨 Error-Specific Solutions

### "VPC has dependencies and cannot be deleted"
```bash
../../nuclear-vpc-cleanup.sh
```

### "Internet Gateway has dependencies"
```bash
../../fix-vpc-dependencies.sh
```

### "Subnet has dependencies"
```bash
../../nuclear-vpc-cleanup.sh
```

### "Security group has dependencies"
```bash
../../cleanup-dependencies.sh
```

### "LoadBalancer service has dependencies"
```bash
../../cleanup-simple.sh
```

## 📊 Script Comparison

### Resources Removed by Each Script

| Resource Type | Simple | Dependencies | Fix VPC | Nuclear |
|---------------|--------|--------------|---------|---------|
| Helm Releases | ❌ | ✅ | ❌ | ❌ |
| K8s Namespaces | ✅ | ✅ | ❌ | ❌ |
| LoadBalancer Services | ✅ | ✅ | ✅ | ✅ |
| PVCs | ✅ | ✅ | ❌ | ❌ |
| ALB Controller | ❌ | ✅ | ✅ | ✅ |
| Elastic IPs | ❌ | ✅ | ✅ | ✅ |
| NAT Gateways | ❌ | ❌ | ✅ | ✅ |
| Network Interfaces | ❌ | ✅ | ✅ | ✅ |
| Security Groups | ❌ | ✅ | ✅ | ✅ |
| EC2 Instances | ❌ | ❌ | ❌ | ✅ |
| VPC Endpoints | ❌ | ❌ | ✅ | ✅ |
| Route Tables | ❌ | ❌ | ❌ | ✅ |
| Subnets | ❌ | ❌ | ❌ | ✅ |
| Internet Gateway | ❌ | ❌ | ❌ | ✅ |

## 🔧 Manual Alternatives

If scripts fail, use these manual commands:

### Release Elastic IPs
```bash
aws ec2 describe-addresses --region us-east-1 --query 'Addresses[].AllocationId' --output text | \
xargs -n1 -I {} aws ec2 release-address --allocation-id {} --region us-east-1
```

### Delete NAT Gateways
```bash
aws ec2 describe-nat-gateways --region us-east-1 --filter "Name=vpc-id,Values=vpc-xxx" --query 'NatGateways[].NatGatewayId' --output text | \
xargs -n1 -I {} aws ec2 delete-nat-gateway --nat-gateway-id {} --region us-east-1
```

### Delete Load Balancers
```bash
aws elbv2 describe-load-balancers --region us-east-1 --query "LoadBalancers[?VpcId=='vpc-xxx'].LoadBalancerArn" --output text | \
xargs -n1 -I {} aws elbv2 delete-load-balancer --load-balancer-arn {} --region us-east-1
```

## 📞 Support

If all scripts fail:
1. Check AWS Console manually
2. Use targeted `terraform destroy -target=resource`
3. Remove resources from state: `terraform state rm resource`
4. Contact AWS Support for stuck resources

## 🎯 Best Practices

1. **Always check first**: Use `check-vpc-dependencies.sh` before cleanup
2. **Start gentle**: Try `cleanup-dependencies.sh` before nuclear option
3. **Wait between attempts**: Allow 60 seconds between cleanup and destroy
4. **Verify results**: Check AWS Console after cleanup
5. **Document issues**: Note which resources were problematic for future reference