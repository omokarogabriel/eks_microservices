# 📚 Detailed EKS Infrastructure Resources Explanation

This document provides comprehensive explanations of every AWS resource created in your EKS infrastructure, what they do, why they're needed, and how they work together.

## 🌐 VPC Module - Network Foundation

### 1. **AWS VPC (Virtual Private Cloud)**
```hcl
resource "aws_vpc" "this"
```
**What it does**: Creates an isolated virtual network in AWS where all your resources live.
**Why needed**: Provides network isolation, security boundaries, and control over IP addressing.
**Key features**:
- **CIDR Block**: Defines IP address range (e.g., 10.0.0.0/16 = 65,536 IP addresses)
- **DNS Support**: Enables hostname resolution within VPC
- **DNS Hostnames**: Allows instances to get public DNS names

### 2. **Internet Gateway (IGW)**
```hcl
resource "aws_internet_gateway" "this"
```
**What it does**: Provides internet access to your VPC.
**Why needed**: Without IGW, resources in VPC cannot reach the internet.
**How it works**: Acts as a bridge between your VPC and the internet for public subnets.

### 3. **Public Subnets**
```hcl
resource "aws_subnet" "public"
```
**What they do**: Host resources that need direct internet access (Load Balancers, NAT Gateways).
**Why needed**: EKS needs public subnets for Load Balancers to receive internet traffic.
**Key features**:
- **map_public_ip_on_launch**: Instances get public IPs automatically
- **kubernetes.io/role/elb**: Tag tells AWS Load Balancer Controller to use these for public ALBs
- **Multi-AZ**: Spread across availability zones for high availability

### 4. **Private Subnets**
```hcl
resource "aws_subnet" "private"
```
**What they do**: Host EKS worker nodes and databases (no direct internet access).
**Why needed**: Security best practice - worker nodes don't need public IPs.
**Key features**:
- **kubernetes.io/role/internal-elb**: Tag for internal Load Balancers
- **No public IPs**: Enhanced security
- **Multi-AZ**: High availability and fault tolerance

### 5. **NAT Gateways**
```hcl
resource "aws_nat_gateway" "this"
```
**What they do**: Allow private subnet resources to access internet for updates/downloads.
**Why needed**: EKS nodes need internet access to pull container images and communicate with EKS API.
**How they work**: 
- Sit in public subnets
- Route outbound traffic from private subnets to internet
- Block inbound traffic from internet
**Cost optimization**: Dev uses 1 NAT Gateway, Prod uses multiple for HA

### 6. **Elastic IPs (EIP)**
```hcl
resource "aws_eip" "nat"
```
**What they do**: Provide static public IP addresses for NAT Gateways.
**Why needed**: NAT Gateways need consistent public IPs for outbound internet access.

### 7. **Route Tables**
```hcl
resource "aws_route_table" "public"
resource "aws_route_table" "private"
```
**What they do**: Define where network traffic should go.
**Public Route Table**: Routes 0.0.0.0/0 → Internet Gateway
**Private Route Table**: Routes 0.0.0.0/0 → NAT Gateway
**Why needed**: Without proper routing, subnets can't reach their destinations.

## 🔒 Security Groups Module - Network Security

### 1. **EKS Cluster Security Group**
```hcl
resource "aws_security_group" "eks_cluster_sg"
```
**What it does**: Controls network access to EKS control plane.
**Rules**:
- **Ingress**: Port 443 from worker nodes (API communication)
- **Purpose**: Secure communication between control plane and nodes

### 2. **EKS Node Security Group**
```hcl
resource "aws_security_group" "eks_node_sg"
```
**What it does**: Controls network access for worker nodes.
**Rules**:
- **Ingress**: Ports 1025-65535 from cluster (kubelet communication)
- **Self-ingress**: All ports from other nodes (pod-to-pod communication)
- **Egress**: All traffic to internet (image pulls, API calls)
**Why needed**: Enables Kubernetes networking while maintaining security.

### 3. **Pod Security Group**
```hcl
resource "aws_security_group" "eks_pod_sg"
```
**What it does**: Additional security for pods using AWS VPC CNI.
**Purpose**: Fine-grained network control for specific applications.
**Rules**: Allow communication within VPC CIDR range.

### 4. **ALB Security Group**
```hcl
resource "aws_security_group" "alb_sg"
```
**What it does**: Controls access to Application Load Balancers.
**Rules**:
- **Ingress**: HTTP (80) and HTTPS (443) from internet
- **Egress**: All traffic (health checks to nodes)
**Why needed**: Public-facing applications need internet access.

### 5. **Database Security Group**
```hcl
resource "aws_security_group" "database_sg"
```
**What it does**: Protects RDS databases.
**Rules**: Only allows access from EKS nodes on database ports (3306-5432).
**Security principle**: Databases only accessible from application layer.

### 6. **Redis Security Group**
```hcl
resource "aws_security_group" "redis_sg"
```
**What it does**: Protects ElastiCache Redis clusters.
**Rules**: Only port 6379 from EKS nodes.
**Purpose**: Secure caching layer access.

## 👤 IAM Roles Module - Identity & Access Management

### 1. **EKS Cluster Service Role**
```hcl
resource "aws_iam_role" "eks_master_role"
```
**What it does**: Allows EKS service to manage AWS resources on your behalf.
**Permissions**: `AmazonEKSClusterPolicy`
**What it can do**:
- Create/manage Load Balancers
- Manage network interfaces
- Call other AWS services for cluster operations
**Trust relationship**: Only EKS service can assume this role.

### 2. **EKS Node Group Role**
```hcl
resource "aws_iam_role" "eks_worker_role"
```
**What it does**: Allows EC2 instances to join EKS cluster and function as worker nodes.
**Permissions**:
- `AmazonEKSWorkerNodePolicy`: Join cluster, register with control plane
- `AmazonEKS_CNI_Policy`: Manage pod networking and IP addresses
- `AmazonEC2ContainerRegistryReadOnly`: Pull container images from ECR
**Trust relationship**: EC2 service can assume this role.

### 3. **EBS CSI Driver Role** (Optional)
```hcl
resource "aws_iam_role" "eks_ebs_csi_driver_role"
```
**What it does**: Allows EBS CSI driver to manage EBS volumes for persistent storage.
**Permissions**: `AmazonEBSCSIDriverPolicy`
**IRSA**: Uses IAM Roles for Service Accounts (no AWS credentials in pods).
**Purpose**: Dynamic provisioning of persistent volumes.

## ☸️ EKS Module - Kubernetes Cluster

### 1. **CloudWatch Log Group**
```hcl
resource "aws_cloudwatch_log_group" "eks"
```
**What it does**: Stores EKS control plane logs.
**Log types captured**:
- **API Server**: All API requests and responses
- **Audit**: Detailed audit trail of cluster activities
- **Authenticator**: Authentication attempts
- **Controller Manager**: Kubernetes controller activities
- **Scheduler**: Pod scheduling decisions
**Retention**: Environment-specific (7-30 days).

### 2. **EKS Cluster**
```hcl
resource "aws_eks_cluster" "this"
```
**What it does**: Creates the managed Kubernetes control plane.
**Components managed by AWS**:
- **API Server**: Kubernetes API endpoint
- **etcd**: Cluster state database
- **Controller Manager**: Manages cluster state
- **Scheduler**: Assigns pods to nodes
**Configuration**:
- **VPC Config**: Network settings, endpoint access
- **Encryption**: KMS encryption for secrets at rest
- **Logging**: Control plane logging to CloudWatch

### 3. **EKS Addons**

#### **VPC CNI Addon**
```hcl
resource "aws_eks_addon" "vpc_cni"
```
**What it does**: Provides pod networking using AWS VPC.
**How it works**: Each pod gets an IP from VPC subnet.
**Benefits**: Native AWS networking, security groups for pods.

#### **CoreDNS Addon**
```hcl
resource "aws_eks_addon" "coredns"
```
**What it does**: Provides DNS resolution for services and pods.
**Purpose**: Service discovery within cluster (e.g., service-name.namespace.svc.cluster.local).

#### **Kube-proxy Addon**
```hcl
resource "aws_eks_addon" "kube_proxy"
```
**What it does**: Implements Kubernetes service networking.
**Purpose**: Load balancing and routing for Kubernetes services.

#### **EBS CSI Driver Addon** (Optional)
```hcl
resource "aws_eks_addon" "ebs_csi_driver"
```
**What it does**: Enables dynamic provisioning of EBS volumes.
**Purpose**: Persistent storage for stateful applications.

### 4. **EKS Node Group**
```hcl
resource "aws_eks_node_group" "this"
```
**What it does**: Manages EC2 instances that run your pods.
**Features**:
- **Auto Scaling**: Automatically adjusts node count based on demand
- **Managed Updates**: AWS handles node updates and patching
- **Instance Types**: Optimized per environment (t3.medium → t3.xlarge)
- **Disk Size**: EBS storage for container images and logs
- **Capacity Type**: On-Demand or Spot instances

## 🔑 KMS Module - Encryption

### 1. **KMS Key**
```hcl
resource "aws_kms_key" "eks"
```
**What it does**: Provides encryption at rest for sensitive data.
**What gets encrypted**:
- Kubernetes secrets stored in etcd
- EBS volumes (node storage)
- Database storage
- CloudWatch logs (optional)
**Key features**:
- **Customer-managed**: You control the key
- **Automatic rotation**: Annual key rotation
- **Fine-grained permissions**: Control who can use the key

### 2. **KMS Alias**
```hcl
resource "aws_kms_alias" "eks"
```
**What it does**: Provides human-readable name for the KMS key.
**Purpose**: Easier key management and identification.

## 🗄️ Database Modules

### RDS Module - Relational Databases

#### **DB Subnet Group**
```hcl
resource "aws_db_subnet_group" "this"
```
**What it does**: Defines which subnets RDS can use.
**Purpose**: Ensures databases are deployed in private subnets only.

#### **DB Parameter Groups**
```hcl
resource "aws_db_parameter_group" "postgresql"
resource "aws_db_parameter_group" "mysql"
```
**What they do**: Customize database engine settings.
**Examples**: Enable query logging, adjust memory settings, tune performance.

#### **PostgreSQL Instance**
```hcl
resource "aws_db_instance" "postgresql"
```
**What it does**: Managed PostgreSQL database for order service.
**Features**:
- **Engine**: PostgreSQL 15.7 (latest stable)
- **Storage**: GP3 SSD with encryption
- **Backups**: Automated daily backups
- **Multi-AZ**: High availability in production
- **Security**: VPC isolation, encryption at rest and in transit

#### **MySQL Instance**
```hcl
resource "aws_db_instance" "mysql"
```
**What it does**: Managed MySQL database for catalog service.
**Features**: Similar to PostgreSQL but optimized for MySQL workloads.

### ElastiCache Module - Redis Caching

#### **Redis Subnet Group**
```hcl
resource "aws_elasticache_subnet_group" "this"
```
**What it does**: Defines subnets for Redis deployment.
**Purpose**: Ensures Redis is in private subnets.

#### **Redis Cluster**
```hcl
resource "aws_elasticache_replication_group" "this"
```
**What it does**: Managed Redis cluster for caching and sessions.
**Features**:
- **Engine**: Redis 7.0 (latest)
- **Encryption**: At rest and in transit
- **Auth Token**: Password-based authentication
- **Clustering**: Multi-node for production
- **Automatic Failover**: High availability

### DynamoDB Module - NoSQL Database

#### **DynamoDB Tables**
```hcl
resource "aws_dynamodb_table" "this"
```
**What they do**: NoSQL tables for cart service and other microservices.
**Features**:
- **Pay-per-request**: Cost-effective billing
- **KMS Encryption**: Customer-managed key encryption
- **Point-in-time Recovery**: Data protection
- **Global Secondary Indexes**: Flexible query patterns
**Use cases**: Shopping cart data, user sessions, product catalog.

## 🔐 Secrets Manager Module

### **Database Secrets**
```hcl
resource "aws_secretsmanager_secret" "database_secrets"
```
**What it does**: Securely stores database credentials and connection strings.
**Contents**:
- Database usernames and passwords
- Connection endpoints
- Port numbers
- Database names
**Security**: KMS encryption, fine-grained access control.
**Integration**: Applications retrieve secrets at runtime via IRSA (no hardcoded credentials).

## 🔐 IRSA Roles Module - Service-Specific IAM Roles

### **Cart Service Role**
```hcl
resource "aws_iam_role" "cart_service_role"
```
**What it does**: Provides cart service with DynamoDB and Secrets Manager access.
**Permissions**:
- DynamoDB read/write operations on cart tables
- Secrets Manager read access for database credentials
- OIDC trust policy for service account authentication
**Trust relationship**: Only cart service account can assume this role.

### **Catalog Service Role**
```hcl
resource "aws_iam_role" "catalog_service_role"
```
**What it does**: Provides catalog service with DynamoDB and Secrets Manager access.
**Permissions**:
- DynamoDB read/write operations on catalog tables
- Secrets Manager read access for database credentials
- OIDC trust policy for service account authentication

### **Order Service Role**
```hcl
resource "aws_iam_role" "order_service_role"
```
**What it does**: Provides order service with PostgreSQL and Secrets Manager access.
**Permissions**:
- Secrets Manager read access for PostgreSQL credentials
- OIDC trust policy for service account authentication
**Database**: Connects to PostgreSQL via retrieved credentials.

### **Checkout Service Role**
```hcl
resource "aws_iam_role" "checkout_service_role"
```
**What it does**: Provides checkout service with Redis and Secrets Manager access.
**Permissions**:
- Secrets Manager read access for Redis credentials
- OIDC trust policy for service account authentication
**Database**: Connects to ElastiCache Redis via retrieved credentials.

### **OIDC Trust Policies**
```hcl
data "aws_iam_policy_document" "irsa_trust_policy"
```
**What they do**: Define which Kubernetes service accounts can assume each role.
**Security features**:
- Environment-specific role isolation
- Service-specific permissions (least privilege)
- No long-term AWS credentials in pods
- Automatic credential rotation via STS tokens

## 🔗 OIDC Module - Service Account Authentication

### **OIDC Identity Provider**
```hcl
resource "aws_iam_openid_connect_identity_provider" "eks"
```
**What it does**: Enables IAM Roles for Service Accounts (IRSA).
**How it works**:
1. EKS creates OIDC identity provider
2. Kubernetes service accounts get JWT tokens
3. AWS STS exchanges tokens for temporary AWS credentials
4. Applications use temporary credentials to access AWS services
**Benefits**: No AWS credentials stored in pods, fine-grained permissions.

### **Service Account Integration**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/cart-service-role
```
**What it does**: Links Kubernetes service accounts to IAM roles.
**Automatic injection**: Helmfile automatically injects role ARNs per environment.
**Security**: Each microservice gets dedicated IAM role with minimal permissions.

## 👥 AWS Auth Module - Kubernetes RBAC

### **aws-auth ConfigMap**
```hcl
resource "kubernetes_config_map" "aws_auth"
```
**What it does**: Maps IAM users/roles to Kubernetes users/groups.
**Purpose**: Enables AWS IAM authentication to Kubernetes API.
**Mappings**:
- Worker node roles → system:nodes group
- Admin users → system:masters group
- Readonly users → custom readonly group

## 👤 Readonly User Module

### **IAM User**
```hcl
resource "aws_iam_user" "readonly"
```
**What it does**: Creates dedicated user for monitoring and troubleshooting.
**Permissions**:
- **AWS**: Can describe EKS clusters and nodes
- **Kubernetes**: Read-only access to all resources
**Use cases**: Monitoring tools, debugging, auditing.

### **Access Keys**
```hcl
resource "aws_iam_access_key" "readonly"
```
**What they do**: Provide programmatic access for the readonly user.
**Security**: Stored in Terraform state, rotated regularly.

## 🚀 GitHub Actions Module

### **OIDC Provider**
```hcl
resource "aws_iam_openid_connect_identity_provider" "github"
```
**What it does**: Enables GitHub Actions to assume AWS roles without long-term credentials.
**Security**: Repository-scoped access, temporary credentials only.

### **GitHub Actions Role**
```hcl
resource "aws_iam_role" "github_actions"
```
**What it does**: Allows GitHub Actions to deploy to EKS.
**Permissions**:
- EKS cluster access
- ECR image pull
- Secrets Manager read
- Scoped to specific cluster resources

## 📦 Helm Chart & Helmfile - Application Deployment

### **Shared Helm Chart** (`helm-chart/`)
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
```
**What it does**: Provides secure, reusable templates for all microservices.
**Security features**:
- **Non-root execution**: All containers run as UID 1000
- **Read-only filesystem**: Immutable runtime environment
- **Dropped capabilities**: Minimal Linux capabilities (ALL dropped)
- **Privilege escalation prevention**: Enhanced security

### **Service Account Template**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    {{- if .Values.irsa.enabled }}
    eks.amazonaws.com/role-arn: {{ .Values.irsa.roleArn }}
    {{- end }}
```
**What it does**: Automatically configures IRSA for each microservice.
**Integration**: Helmfile injects environment-specific role ARNs.

### **Database Secret Template**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ .Values.serviceName }}-db-secret
data:
  {{- range $key, $value := .Values.database.secrets }}
  {{ $key }}: {{ $value | b64enc }}
  {{- end }}
```
**What it does**: Creates Kubernetes secrets from database credentials.
**Security**: Credentials retrieved from AWS Secrets Manager via IRSA.

### **Helmfile Configuration** (`helmfile.yaml`)
```yaml
releases:
- name: cart
  chart: ./helm-chart
  values:
  - ./helm-chart/microservices/cart/values.yaml
  set:
  - name: irsa.roleArn
    value: {{ requiredEnv "CART_ROLE_ARN" }}
```
**What it does**: Manages multi-environment deployments with automated configuration.
**Features**:
- **Environment-aware**: Automatic dev/staging/prod value injection
- **IRSA integration**: Dynamic role ARN assignment per service
- **Credential management**: Automated database secret retrieval
- **Namespace management**: Automatic retail-store namespace creation

### **Deployment Automation** (`deploy-helmfile.sh`)
```bash
#!/bin/bash
ENVIRONMENT=$1

# Get IRSA role ARNs from Terraform
export CART_ROLE_ARN=$(terraform output -raw cart_service_role_arn)
export CATALOG_ROLE_ARN=$(terraform output -raw catalog_service_role_arn)

# Deploy with environment-specific values
helmfile -e $ENVIRONMENT apply
```
**What it does**: Automates deployment with secure credential injection.
**Integration**: Works with both local development and GitHub Actions.

## 🏷️ Tagging Strategy

### **Common Tags**
Applied to all resources for:
- **Cost allocation**: Track spending by environment/project
- **Resource organization**: Group related resources
- **Automation**: Enable automated operations
- **Compliance**: Meet organizational requirements

**Tag categories**:
- **Cost**: Environment, Project, Owner, CostCenter
- **Operational**: ManagedBy, CreatedDate, Backup
- **Business**: BusinessUnit, Application

## 🔄 Resource Dependencies

### **Dependency Chain**:
1. **VPC** → Subnets, IGW, NAT Gateways
2. **Security Groups** → Reference VPC and each other
3. **IAM Roles** → Used by EKS cluster and nodes
4. **KMS Keys** → Used for encryption across services
5. **EKS Cluster** → Uses VPC, security groups, IAM roles
6. **Node Groups** → Depend on EKS cluster
7. **Databases** → Use VPC subnets and security groups
8. **OIDC** → Depends on EKS cluster
9. **IRSA Roles** → Depend on OIDC provider and databases
10. **AWS Auth** → Depends on EKS cluster and IAM roles
11. **Helmfile** → Depends on IRSA roles and database secrets

## 🎯 Environment-Specific Configurations

### **Development**:
- Single NAT Gateway (cost optimization)
- Smaller instance types (t3.medium)
- Public API endpoint (developer access)
- Shorter log retention (7 days)
- Optional backups

### **Staging**:
- Multiple NAT Gateways (HA testing)
- Medium instance types (t3.large)
- Private API endpoint
- Medium log retention (14 days)
- Required backups

### **Production**:
- Multiple NAT Gateways (high availability)
- Large instance types (t3.xlarge)
- Private API endpoint
- Long log retention (30 days)
- Required backups with cross-region replication
- Deletion protection enabled
- Enhanced security contexts
- Full IRSA implementation

## 🔍 Microservice-Specific Configurations

### **Cart Service**:
- **Database**: DynamoDB tables for shopping cart data
- **IRSA Role**: DynamoDB read/write, Secrets Manager read
- **Security Context**: Non-root (UID 1000), read-only filesystem
- **Resources**: CPU/memory limits with HPA scaling

### **Catalog Service**:
- **Database**: DynamoDB tables for product catalog
- **IRSA Role**: DynamoDB read/write, Secrets Manager read
- **Security Context**: Non-root (UID 1000), read-only filesystem
- **Resources**: CPU/memory limits with HPA scaling

### **Order Service**:
- **Database**: PostgreSQL for order management
- **IRSA Role**: Secrets Manager read for PostgreSQL credentials
- **Security Context**: Non-root (UID 1000), read-only filesystem
- **Resources**: CPU/memory limits with HPA scaling

### **Checkout Service**:
- **Database**: ElastiCache Redis for session management
- **IRSA Role**: Secrets Manager read for Redis credentials
- **Security Context**: Non-root (UID 1000), read-only filesystem
- **Resources**: CPU/memory limits with HPA scaling

### **UI Service**:
- **Purpose**: Frontend application serving the retail store interface
- **Security Context**: Non-root (UID 1000), read-only filesystem
- **Resources**: CPU/memory limits with HPA scaling
- **Ingress**: ALB integration for public access

## 🛡️ Security Architecture

### **Defense in Depth**:
1. **Network Security**: VPC isolation, private subnets, security groups
2. **Container Security**: Non-root execution, read-only filesystems, dropped capabilities
3. **Identity Security**: IRSA with service-specific roles, OIDC authentication
4. **Data Security**: KMS encryption, Secrets Manager, secure credential injection
5. **Access Security**: RBAC, least-privilege permissions, temporary credentials

### **Zero-Trust Principles**:
- **No long-term credentials**: All authentication via temporary tokens
- **Service isolation**: Each microservice has dedicated IAM role
- **Encrypted communication**: TLS everywhere, encrypted storage
- **Audit trail**: Complete logging and monitoring
- **Principle of least privilege**: Minimal permissions per service

## 🚀 Deployment Workflows

### **Infrastructure + Helmfile (Recommended)**:
1. **Terraform**: Creates infrastructure with IRSA roles
2. **Automatic trigger**: Helmfile deployment starts after infrastructure
3. **IRSA injection**: Role ARNs automatically injected per environment
4. **Credential retrieval**: Database secrets fetched via IRSA
5. **Secure deployment**: All microservices deployed with proper security contexts

### **Helmfile Only**:
1. **Environment detection**: Automatic dev/staging/prod configuration
2. **Role injection**: IRSA roles retrieved from existing infrastructure
3. **Credential management**: Secure database connection setup
4. **Health checks**: Automated deployment validation

### **Local Development**:
```bash
# Deploy to specific environment
./deploy-helmfile.sh dev
./deploy-helmfile.sh staging
./deploy-helmfile.sh prod
```

This infrastructure provides a production-ready, secure, and scalable foundation for running microservices on Amazon EKS with comprehensive IRSA security, automated Helmfile deployment, container hardening, and operational capabilities.