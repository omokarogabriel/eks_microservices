# Microservices EKS Infrastructure

Production-ready Amazon EKS infrastructure with Terraform modules for multi-environment deployment. This project creates a complete Kubernetes platform with **PostgreSQL, MySQL, Redis, DynamoDB**, security, monitoring, and **GitHub Actions CI/CD** integration.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Architecture Overview](#architecture-overview)
- [Detailed Resource Documentation](#detailed-resource-documentation)
- [Environment Configurations](#environment-configurations)
- [Security Features](#security-features)
- [Monitoring & Logging](#monitoring--logging)
- [Cost Optimization](#cost-optimization)
- [Troubleshooting](#troubleshooting)

## 🚀 Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- kubectl (for cluster interaction)
- Unique S3 bucket names (globally unique across AWS)

## ⚡ Quick Start

### 1. Backend Setup (Required First)

Create S3 buckets and DynamoDB table for Terraform state management:

```bash
cd backend-setup
terraform init
terraform plan
terraform apply
```

### 2. Deploy Environment

Choose your environment and deploy:

```bash
# Development
cd environments/dev
terraform init
terraform plan
terraform apply

# Staging  
cd environments/staging
terraform init
terraform plan
terraform apply

# Production
cd environments/prod
terraform init
terraform plan
terraform apply
```

### 3. Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name <cluster-name>
kubectl get nodes
```

### 4. Setup GitHub Actions

```bash
# Get GitHub Actions role ARN
cd environments/prod
terraform output github_actions_role_arn

# Add to GitHub repository secrets:
# AWS_ROLE_ARN_DEV = arn:aws:iam::438465156402:role/retail-store-dev-github-actions-role
# AWS_ROLE_ARN_STAGING = arn:aws:iam::438465156402:role/retail-store-staging-github-actions-role
# AWS_ROLE_ARN_PROD = arn:aws:iam::438465156402:role/retail-store-prod-github-actions-role
```

### 5. Deploy with GitHub Actions

**Option 1: Infrastructure + Applications (Recommended)**
```bash
# Go to GitHub Actions
# Select "Deploy Infrastructure" workflow
# Choose environment and "apply" action
# Applications deploy automatically
```

**Option 2: Applications Only**
```bash
# Go to GitHub Actions
# Select "Deploy Applications" workflow
# Provide cluster name from Terraform output
```

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Account                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │   Dev VPC       │  │  Staging VPC    │  │   Prod VPC   │ │
│  │  10.0.0.0/16    │  │  10.1.0.0/16    │  │ 10.2.0.0/16  │ │
│  │  • EKS Cluster  │  │  • EKS Cluster  │  │ • EKS Cluster │ │
│  │  • PostgreSQL   │  │  • PostgreSQL   │  │ • PostgreSQL  │ │
│  │  • MySQL        │  │  • MySQL        │  │ • MySQL       │ │
│  │  • Redis        │  │  • Redis        │  │ • Redis       │ │
│  │  • DynamoDB     │  │  • DynamoDB     │  │ • DynamoDB    │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 Shared Resources                        │ │
│  │  • KMS Keys (per environment)                          │ │
│  │  • S3 State Buckets (per environment)                  │ │
│  │  • DynamoDB State Lock Table (shared)                  │ │
│  │  • CloudWatch Log Groups                               │ │
│  │  • AWS Secrets Manager                                 │ │
│  │  • GitHub Actions OIDC Provider                        │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 📚 Detailed Resource Documentation

### 🌐 VPC Module (`modules/vpc/`)

Creates a complete network foundation for EKS:

**Resources Created:**
- **VPC**: Main virtual private cloud with DNS support
- **Public Subnets**: 2-3 subnets for load balancers and NAT gateways
- **Private Subnets**: 2-3 subnets for EKS worker nodes (isolated)
- **Internet Gateway**: Provides internet access to public subnets
- **NAT Gateways**: Enable outbound internet for private subnets
- **Route Tables**: Separate routing for public and private subnets
- **Elastic IPs**: Static IPs for NAT gateways

**Configuration:**
```hcl
# Dev: Single NAT Gateway (cost optimization)
single_nat_gateway = true

# Staging/Prod: Multiple NAT Gateways (high availability)
single_nat_gateway = false
```

**Security Features:**
- Private subnets have no direct internet access
- NAT gateways provide secure outbound connectivity
- Route tables enforce network segmentation

### 🔒 Security Groups Module (`modules/security_groups/`)

Implements defense-in-depth network security:

**Security Groups Created:**

1. **EKS Cluster Security Group**
   - Allows communication between cluster and nodes
   - Restricts API server access to authorized sources

2. **EKS Node Security Group**
   - Node-to-node communication within cluster
   - Allows kubelet and kube-proxy traffic
   - SSH access (if enabled)

3. **EKS Pod Security Group**
   - Pod-to-pod communication
   - Application-specific traffic rules

4. **ALB Security Group**
   - HTTP (80) and HTTPS (443) from internet
   - Outbound to EKS nodes for health checks

**Traffic Flow:**
```
Internet → ALB SG → EKS Nodes → Pod SG → Applications
```

### 🔐 IAM Roles Module (`modules/iam_role/`)

Creates least-privilege IAM roles for EKS components:

**Roles Created:**

1. **EKS Cluster Service Role**
   - Policies: `AmazonEKSClusterPolicy`
   - Purpose: Allows EKS to manage AWS resources

2. **EKS Node Group Role**
   - Policies: 
     - `AmazonEKSWorkerNodePolicy`
     - `AmazonEKS_CNI_Policy`
     - `AmazonEC2ContainerRegistryReadOnly`
   - Purpose: Allows worker nodes to join cluster and pull images

3. **EBS CSI Driver Role** (IRSA)
   - Policies: `AmazonEBSCSIDriverPolicy`
   - Purpose: Manages EBS volumes for persistent storage
   - Uses OIDC for secure token exchange

**Security Features:**
- Roles use temporary credentials (no long-term keys)
- Principle of least privilege
- IRSA eliminates need for AWS credentials in pods

### ☸️ EKS Module (`modules/eks/`)

Creates the managed Kubernetes cluster with production-ready configuration:

**Main Resources:**

1. **EKS Cluster**
   - Kubernetes version: 1.28 (configurable)
   - Private API endpoint (production)
   - Encryption at rest using KMS
   - CloudWatch logging enabled

2. **EKS Node Group**
   - Managed worker nodes in private subnets
   - Auto Scaling Group with desired/min/max configuration
   - Instance types optimized per environment
   - EBS-optimized instances with encryption

3. **EKS Addons** (Essential)
   - **vpc-cni**: Pod networking and IP management
   - **coredns**: DNS resolution for services and pods
   - **kube-proxy**: Service networking and load balancing
   - **aws-ebs-csi-driver**: EBS volume provisioning

**Configuration by Environment:**
```yaml
Dev:
  - Instance: t3.medium
  - Nodes: 2-4 (desired: 2)
  - Disk: 20GB
  - Public API: Enabled (development access)

Staging:
  - Instance: t3.large  
  - Nodes: 2-6 (desired: 3)
  - Disk: 30GB
  - Public API: Disabled

Production:
  - Instance: t3.xlarge
  - Nodes: 3-12 (desired: 6)
  - Disk: 50GB
  - Public API: Disabled
  - Log Retention: 30 days
```

### 🔑 KMS Module (`modules/kms/`)

Provides encryption at rest for sensitive data:

**Resources:**
- **KMS Key**: Customer-managed key for EKS secrets encryption
- **Key Alias**: Human-readable alias for key management
- **Key Policy**: Allows EKS service and root account access

**What Gets Encrypted:**
- Kubernetes secrets stored in etcd
- CloudWatch logs (optional)
- EBS volumes (node storage)

**Key Rotation:**
- Automatic annual rotation enabled
- Deletion window: 7 days (dev), 10 days (staging), 30 days (prod)

### 🆔 OIDC Provider Module (`modules/oidc/`)

Enables IAM Roles for Service Accounts (IRSA):

**Purpose:**
- Allows Kubernetes service accounts to assume IAM roles
- Eliminates need for AWS credentials in pods
- Provides fine-grained permissions per application

**How It Works:**
1. EKS creates OIDC identity provider
2. Service accounts get JWT tokens
3. AWS STS exchanges tokens for temporary credentials
4. Applications use temporary credentials to access AWS services

**Example Usage:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-service-account
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/MyRole
```

### 👤 Readonly User Module (`modules/readonly-user/`)

Creates a dedicated user for monitoring and troubleshooting:

**Resources Created:**
- **IAM User**: `{cluster-name}-readonly-user`
- **Access Keys**: For programmatic access
- **IAM Policy**: Minimal EKS describe permissions
- **Kubernetes ClusterRole**: Read-only access to all resources
- **ClusterRoleBinding**: Maps IAM user to Kubernetes permissions

**Permissions:**
- **AWS**: Can describe EKS clusters and nodes
- **Kubernetes**: Can view all resources (get, list, watch)
- **Cannot**: Create, update, delete, or exec into resources

### 🗺️ AWS Auth Module (`modules/aws-auth/`)

Manages the aws-auth ConfigMap for IAM to Kubernetes RBAC mapping:

**Purpose:**
- Maps IAM users/roles to Kubernetes users/groups
- Enables AWS IAM authentication to Kubernetes API
- Automatically includes worker node roles

**Default Mappings:**
```yaml
mapRoles:
  - rolearn: arn:aws:iam::ACCOUNT:role/NodeInstanceRole
    username: system:node:{{EC2PrivateDNSName}}
    groups:
      - system:bootstrappers
      - system:nodes
  - rolearn: arn:aws:iam::ACCOUNT:user/readonly-user
    username: readonly-user
    groups:
      - eks-readonly
```

### 🗄️ Database Modules

#### RDS Module (`modules/databases/rds/`)
Creates managed PostgreSQL and MySQL databases:

**Resources:**
- **PostgreSQL 15**: Production-ready with parameter groups
- **MySQL 8.0**: Optimized configuration with logging
- **Encryption**: KMS encryption at rest and in transit
- **Backups**: Automated backups with configurable retention
- **Multi-AZ**: High availability for staging/production

#### ElastiCache Module (`modules/databases/elasticache/`)
Creates Redis cluster for caching and sessions:

**Features:**
- **Redis 7.0**: Latest version with enhanced security
- **Encryption**: At rest and in transit encryption
- **Auth Token**: Password-based authentication
- **Clustering**: Multi-node setup for production
- **Snapshots**: Automated backup and recovery

#### DynamoDB Module (`modules/databases/dynamodb/`)
Creates NoSQL tables for microservices:

**Configuration:**
- **Pay-per-request**: Cost-effective billing
- **KMS Encryption**: Customer-managed key encryption
- **Point-in-time Recovery**: Production data protection
- **Global Secondary Indexes**: Flexible query patterns

#### Secrets Manager Module (`modules/secrets-manager/`)
Securely stores database credentials:

**Security:**
- **KMS Encryption**: All secrets encrypted
- **Automatic Rotation**: Supports credential rotation
- **Fine-grained Access**: IAM-based access control
- **Kubernetes Integration**: Easy retrieval from pods

### 🚀 GitHub Actions Module (`modules/github-actions/`)

Enables secure CI/CD without long-term credentials:

**Resources:**
- **OIDC Provider**: GitHub Actions identity provider
- **IAM Role**: Scoped permissions for deployments
- **Repository Access**: Restricted to specific GitHub repo

**Permissions:**
- EKS cluster access for deployments
- ECR image pull permissions
- Secrets Manager read access
- Scoped to cluster resources only

### 📊 CloudWatch Logging

**Log Groups Created:**
- `/aws/eks/{cluster-name}/cluster`: EKS control plane logs

**Log Types Captured:**
- **API Server**: Kubernetes API requests and responses
- **Audit**: Detailed audit trail of all API calls
- **Authenticator**: Authentication attempts and results
- **Controller Manager**: Kubernetes controller activities
- **Scheduler**: Pod scheduling decisions

**Retention:**
- Dev: 7 days
- Staging: 14 days  
- Production: 30 days

## 🚀 GitHub Actions CI/CD

### Automated Deployment Workflows

**1. Deploy Infrastructure (`infrastructure-deploy.yml`)**
- Deploys Terraform infrastructure
- Automatically triggers application deployment
- Supports plan/apply/destroy actions
- Environment-specific role assumption

**2. Deploy Applications (`deploy-apps.yml`)**
- Deploys all 5 Gabriel Retail Store microservices
- Installs AWS Load Balancer Controller
- Waits for cluster readiness
- Comprehensive health checks

### Security Features
**OIDC Integration:**
- No long-term AWS credentials stored
- Environment-specific IAM roles
- Repository-scoped access control
- Account ID: 438465156402

**Database Integration:**
- Automatic secrets retrieval from AWS Secrets Manager
- Environment-specific database connections
- Secure credential injection into pods

### Usage
**Infrastructure + Applications (Recommended):**
1. Go to Actions tab → "Deploy Infrastructure"
2. Choose environment (dev/staging/prod)
3. Choose action: "apply"
4. Applications deploy automatically after infrastructure

**Applications Only:**
1. Go to Actions tab → "Deploy Applications"
2. Choose environment and provide cluster name
3. Microservices deploy to existing cluster

**Infrastructure Destruction:**
1. Go to Actions tab → "Deploy Infrastructure"
2. Choose environment and action: "destroy"
3. Confirm destruction

## 🧹 Cleanup & Troubleshooting

### Dependency Cleanup Scripts

If `terraform destroy` fails due to dependencies, use these cleanup scripts:

```bash
# Navigate to environment
cd environments/dev

# Check what dependencies exist
../../check-vpc-dependencies.sh

# Option 1: Standard cleanup
../../cleanup-dependencies.sh

# Option 2: Nuclear cleanup (for persistent issues)
../../nuclear-vpc-cleanup.sh

# Then retry destroy
terraform destroy
```

**Available Scripts:**
- `cleanup-dependencies.sh` - Full Kubernetes and AWS cleanup
- `nuclear-vpc-cleanup.sh` - Removes ALL VPC dependencies
- `fix-vpc-dependencies.sh` - Targeted network cleanup
- `check-vpc-dependencies.sh` - Diagnose remaining dependencies
- `cleanup-simple.sh` - Basic cleanup with minimal tools

**See [CLEANUP_GUIDE.md](CLEANUP_GUIDE.md) for detailed troubleshooting.**

## 🌍 Environment Configurations

### Development Environment
**Purpose**: Development and testing
**Configuration**:
- **Cost Optimized**: Single NAT gateway, smaller instances
- **Access**: Public API endpoint for developer access
- **Scaling**: 1-4 nodes, t3.medium instances
- **Storage**: 20GB EBS volumes
- **Databases**: Basic PostgreSQL, MySQL, Redis, 1 DynamoDB table
- **Backup**: Optional
- **Auto-shutdown**: Enabled for cost savings

### Staging Environment  
**Purpose**: Pre-production testing and validation
**Configuration**:
- **High Availability**: Multi-AZ NAT gateways
- **Security**: Private API endpoint
- **Scaling**: 2-6 nodes, t3.large instances
- **Storage**: 30GB EBS volumes
- **Databases**: Standard PostgreSQL, MySQL, Redis, 2 DynamoDB tables
- **Backup**: Required
- **Monitoring**: Enhanced

### Production Environment
**Purpose**: Live production workloads
**Configuration**:
- **Enterprise Grade**: Maximum security and availability
- **Compliance**: SOX compliance tags and controls
- **Scaling**: 3-12 nodes, t3.xlarge instances
- **Storage**: 50GB EBS volumes
- **Databases**: Multi-AZ PostgreSQL, MySQL, Redis cluster, 2 DynamoDB tables
- **Backup**: Required with cross-region replication
- **Monitoring**: Full observability stack
- **Maintenance Window**: Sunday 2AM UTC

## 🔐 Security Features

### Container Security
- **Non-Root Execution**: All containers run as UID 1000
- **Read-Only Filesystem**: Immutable runtime environment
- **Capability Dropping**: Minimal Linux capabilities
- **Privilege Escalation**: Prevention enabled

### Network Security
- **Private Subnets**: Worker nodes isolated from internet
- **Security Groups**: Least-privilege network access
- **ALB Integration**: Secure ingress with AWS Load Balancer
- **Service Mesh Ready**: Prepared for Istio/Linkerd integration

### Identity & Access Management
- **OIDC Authentication**: GitHub Actions with temporary credentials
- **IRSA**: Secure service account authentication
- **RBAC**: Kubernetes role-based access control
- **Environment Isolation**: Separate roles per environment

### Encryption & Secrets
- **AWS Secrets Manager**: Secure credential storage
- **KMS Encryption**: Customer-managed keys
- **In-Transit**: TLS for all communications
- **Credential Rotation**: Automated rotation support

### Compliance & Monitoring
- **Security Contexts**: Pod and container security policies
- **Resource Limits**: Prevent resource exhaustion attacks
- **Health Checks**: Automated failure detection
- **Audit Logging**: Complete security audit trail

## 📈 Monitoring & Logging

### CloudWatch Integration
- **Metrics**: Cluster and node performance metrics
- **Logs**: Centralized log aggregation
- **Alarms**: Automated alerting for critical events
- **Dashboards**: Real-time visibility

### Observability Stack
- **Control Plane Logs**: EKS API server, scheduler, controller manager
- **Application Logs**: Container stdout/stderr
- **Infrastructure Metrics**: CPU, memory, disk, network
- **Custom Metrics**: Application-specific metrics

### Log Retention Strategy
```yaml
Environment | Retention | Purpose
------------|-----------|--------
Dev         | 7 days    | Short-term debugging
Staging     | 14 days   | Integration testing
Production  | 30 days   | Compliance and troubleshooting
```

## 💰 Cost Optimization

### Environment-Specific Sizing
- **Dev**: Minimal resources for development
- **Staging**: Moderate resources for testing
- **Prod**: Right-sized for production workloads

### Auto-Scaling
- **Cluster Autoscaler**: Automatically adjusts node count
- **Horizontal Pod Autoscaler**: Scales pods based on metrics
- **Vertical Pod Autoscaler**: Optimizes resource requests

### Cost Allocation Tags
```yaml
CostCenter: engineering
Project: microservices-eks
Environment: dev/staging/prod
Owner: devops-team
BusinessUnit: platform
```

### Spot Instances (Optional)
- Can be enabled for non-critical workloads
- Up to 90% cost savings
- Automatic handling of spot interruptions

## 🔧 Troubleshooting

### Terraform Destroy Issues

**Problem**: `terraform destroy` fails with dependency violations

**Solution**: Use cleanup scripts before destroying
```bash
cd environments/dev
../../nuclear-vpc-cleanup.sh  # For persistent VPC issues
terraform destroy
```

**Problem**: "VPC has dependencies and cannot be deleted"

**Solution**: 
```bash
../../check-vpc-dependencies.sh  # See what's left
../../nuclear-vpc-cleanup.sh     # Remove everything
terraform destroy
```

**Problem**: "File is larger than GitHub's maximum file size"

**Solution**: Remove large Terraform files from Git history
```bash
pip install git-filter-repo
git filter-repo --path environments/dev/.terraform --invert-paths
git push origin dev --force
```

### Common Issues

**1. Cluster Access Issues**
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name cluster-name

# Check IAM permissions
aws sts get-caller-identity

# Verify aws-auth ConfigMap
kubectl get configmap aws-auth -n kube-system -o yaml
```

**2. Node Group Issues**
```bash
# Check node status
kubectl get nodes

# Describe node for events
kubectl describe node <node-name>

# Check node group in AWS console
aws eks describe-nodegroup --cluster-name <cluster> --nodegroup-name <nodegroup>
```

**3. Pod Networking Issues**
```bash
# Check VPC CNI pods
kubectl get pods -n kube-system -l k8s-app=aws-node

# Verify security groups
aws ec2 describe-security-groups --group-ids <sg-id>

# Test DNS resolution
kubectl run test-pod --image=busybox --rm -it -- nslookup kubernetes.default
```

**4. Storage Issues**
```bash
# Check EBS CSI driver
kubectl get pods -n kube-system -l app=ebs-csi-controller

# Verify storage classes
kubectl get storageclass

# Check persistent volumes
kubectl get pv,pvc --all-namespaces
```

### Useful Commands

```bash
# Get cluster info
kubectl cluster-info

# Check all system pods
kubectl get pods --all-namespaces

# View cluster events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Access readonly user credentials
terraform output -json readonly_user_credentials
```

### Support Resources
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)

---

## 📝 Notes

- **Bucket Names**: S3 bucket names must be globally unique. Update bucket names in `backend-setup/main.tf` and environment `backend.tf` files.
- **Region**: Default region is `us-east-1`. Update in all `terraform.tfvars` files if needed.
- **Kubernetes Version**: Currently set to 1.28. Update as needed for latest features and security patches.
- **Instance Types**: Adjust based on workload requirements and cost considerations.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test thoroughly
4. Submit a pull request with detailed description

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.