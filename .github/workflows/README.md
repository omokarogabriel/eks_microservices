# GitHub Actions Workflows

## 🚀 Available Workflows

### 1. **Setup Backend** (`setup-backend.yml`)
- **Purpose**: Create S3 bucket and DynamoDB table for Terraform state
- **Trigger**: Manual only
- **Usage**: Run this FIRST before any other workflows

### 2. **Deploy Infrastructure** (`infrastructure-deploy.yml`)
- **Purpose**: Deploy complete EKS infrastructure + applications
- **Trigger**: Manual only
- **Usage**: Main deployment workflow (recommended)

### 3. **Deploy Applications Only** (`deploy-applications.yml`)
- **Purpose**: Deploy only microservices to existing cluster
- **Trigger**: Manual only
- **Usage**: When cluster exists but need to redeploy apps

### 4. **Destroy Infrastructure** (`destroy-infrastructure.yml`)
- **Purpose**: Safely destroy all infrastructure
- **Trigger**: Manual only
- **Safety**: Requires typing "DESTROY" to confirm

### 5. **Validate Terraform** (`validate-terraform.yml`)
- **Purpose**: Validate Terraform and Helm syntax
- **Trigger**: Pull requests to main branch
- **Usage**: Automatic validation on PRs

### 6. **Deploy to EKS** (`deploy.yml`) - ⚠️ DISABLED
- **Status**: DISABLED for safety
- **Reason**: Was auto-deploying to production on push
- **Alternative**: Use "Deploy Infrastructure" instead

## 🛡️ Safety Features

- **No Automatic Deployments**: All workflows require manual trigger
- **Environment Isolation**: Separate AWS roles per environment
- **Confirmation Required**: Destroy operations need explicit confirmation
- **Validation**: PR validation prevents broken deployments

## 📋 Required GitHub Secrets

```
AWS_ROLE_ARN_DEV     = arn:aws:iam::438465156402:role/retail-store-dev-github-actions-role
AWS_ROLE_ARN_STAGING = arn:aws:iam::438465156402:role/retail-store-staging-github-actions-role
AWS_ROLE_ARN_PROD    = arn:aws:iam::438465156402:role/retail-store-prod-github-actions-role
```

## 🔄 Deployment Order

1. **Setup Backend** (once)
2. **Deploy Infrastructure** (per environment)
3. **Deploy Applications Only** (optional, for app updates)

## ⚠️ Important Notes

- Never push directly to main without PR validation
- Always test in dev environment first
- Use destroy workflow carefully - it's irreversible
- Check AWS costs regularly