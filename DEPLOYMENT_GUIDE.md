# Gabriel Retail Store Deployment Guide

## 🚀 Deployment Options

### Option 1: Infrastructure + Applications (Recommended)
Deploy infrastructure and applications in one workflow:

```bash
# Go to GitHub Actions
# Select "Deploy Infrastructure" workflow
# Choose environment: dev/staging/prod
# Choose action: apply
# This will automatically deploy applications after infrastructure
```

### Option 2: Separate Deployment
Deploy infrastructure and applications separately:

```bash
# 1. Deploy Infrastructure
# GitHub Actions → "Deploy Infrastructure" → action: apply

# 2. Deploy Applications  
# GitHub Actions → "Deploy Applications" → provide cluster name
```

## 📋 Prerequisites

### GitHub Secrets Required:
```
AWS_ROLE_ARN_DEV = arn:aws:iam::438465156402:role/retail-store-dev-github-actions-role
AWS_ROLE_ARN_STAGING = arn:aws:iam::438465156402:role/retail-store-staging-github-actions-role  
AWS_ROLE_ARN_PROD = arn:aws:iam::438465156402:role/retail-store-prod-github-actions-role
```

## 🔧 Chart Issues Fixed

### Security Improvements:
- ✅ Added pod and container security contexts
- ✅ Run as non-root user (UID 1000)
- ✅ Read-only root filesystem
- ✅ Dropped all capabilities

### Configuration Fixes:
- ✅ Added missing MySQL database name and username
- ✅ Made AWS region configurable
- ✅ Fixed namespace fallback to "microservice"
- ✅ Removed redundant ingress annotation
- ✅ Changed image tag from "latest" to "1.0.0"

### Database Configuration:
- ✅ PostgreSQL: Complete environment variables
- ✅ MySQL: Added missing RETAIL_CATALOG_PERSISTENCE_NAME/USERNAME
- ✅ Redis: Proper URL format for checkout service
- ✅ DynamoDB: Configurable AWS region

## 🏪 Microservices Deployed

### 1. Cart Service
- **Image**: `public.ecr.aws/aws-containers/retail-store-sample-cart:1.2.4`
- **Database**: DynamoDB + Redis
- **Port**: 8080
- **Health**: `/actuator/health`

### 2. Catalog Service  
- **Image**: `public.ecr.aws/aws-containers/retail-store-sample-catalog:1.2.4`
- **Database**: MySQL
- **Port**: 8080
- **Health**: `/health`

### 3. Order Service
- **Image**: `public.ecr.aws/aws-containers/retail-store-sample-orders:1.2.4`
- **Database**: PostgreSQL
- **Port**: 8080
- **Health**: `/actuator/health`

### 4. Checkout Service
- **Image**: `public.ecr.aws/aws-containers/retail-store-sample-checkout:1.2.4`
- **Database**: Redis
- **Port**: 8080
- **Health**: `/health`

### 5. UI Service
- **Image**: `public.ecr.aws/aws-containers/retail-store-sample-ui:1.2.4`
- **Database**: None (Frontend)
- **Port**: 8080
- **Health**: `/actuator/health`
- **Ingress**: ALB with internet access

## 🔍 Verification Commands

```bash
# Check deployments
kubectl get all -n retail-store-dev

# Check ingress
kubectl get ingress -n retail-store-dev

# Get application URL
kubectl get ingress ui -n retail-store-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Check pod logs
kubectl logs -f deployment/ui -n retail-store-dev
```

## 🌐 Access Application

After deployment, get the ALB URL:
```bash
ALB_URL=$(kubectl get ingress ui -n retail-store-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Application URL: http://${ALB_URL}"
```

## 🔧 Troubleshooting

### Common Issues:
1. **Pods not starting**: Check database connectivity
2. **Ingress not ready**: Wait for ALB provisioning (5-10 minutes)
3. **Service unavailable**: Check security groups allow ALB → pods traffic

### Debug Commands:
```bash
# Check pod status
kubectl describe pod <pod-name> -n retail-store-dev

# Check service endpoints
kubectl get endpoints -n retail-store-dev

# Check ALB controller logs
kubectl logs -f deployment/aws-load-balancer-controller -n kube-system
```