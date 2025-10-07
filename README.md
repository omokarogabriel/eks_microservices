# Microservices EKS Infrastructure

This project provides a complete infrastructure setup for deploying microservices on Amazon EKS using Terraform and Helmfile.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- kubectl
- Helm >= 3.0
- Helmfile

## Installation

### 1. Install Helmfile

**Linux:**
```bash
wget https://github.com/helmfile/helmfile/releases/download/v0.158.1/helmfile_0.158.1_linux_amd64.tar.gz
tar -xzf helmfile_0.158.1_linux_amd64.tar.gz
mkdir -p ~/bin
mv helmfile ~/bin/
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/bin:$PATH"
```

**macOS:**
```bash
brew install helmfile
```

**Windows (using scoop):**
```bash
scoop install helmfile
```

### 2. Install Helm Diff Plugin
```bash
helm plugin install https://github.com/databus23/helm-diff
```

### 3. Initialize Helmfile
```bash
helmfile init
```

### 4. Verify Installation
```bash
helmfile --version
helm plugin list
```

## Project Structure

```
microservices_eks/
├── environments/
│   ├── dev/
│   └── prod/
├── modules/
│   ├── vpc/
│   ├── eks/
│   ├── databases/
│   └── ...
├── helm-chart/
├── helmfile.yaml
└── deploy-helmfile.sh
```

## Deployment

### 1. Deploy Infrastructure
```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

### 2. Deploy Applications
```bash
# Make sure the script is executable
chmod +x deploy-helmfile.sh

# Deploy to dev environment
./deploy-helmfile.sh dev
```

**Note**: The deployment script automatically:
- Retrieves database credentials from AWS Secrets Manager
- Gets IRSA role ARNs from Terraform outputs
- Exports environment variables for Helmfile
- Deploys all microservices using Helmfile

## Features

- **Infrastructure as Code**: Complete EKS cluster setup with Terraform
- **Database Support**: PostgreSQL, MySQL, Redis, and DynamoDB
- **Security**: KMS encryption, IAM roles, and security groups
- **Monitoring**: CloudWatch integration
- **CI/CD**: GitHub Actions integration
- **Multi-Environment**: Separate dev/prod configurations

## Architecture

The infrastructure includes:
- VPC with public/private subnets
- EKS cluster with managed node groups
- RDS (PostgreSQL, MySQL)
- ElastiCache (Redis)
- DynamoDB tables
- Secrets Manager for database credentials
- IRSA roles for service authentication

## Services

- **Cart Service**: Uses DynamoDB and Redis
- **Catalog Service**: Uses MySQL
- **Order Service**: Uses PostgreSQL
- **Checkout Service**: Uses Redis

## Verification

After deployment, verify the setup:
```bash
kubectl get pods -n retail-store-dev
kubectl get svc -n retail-store-dev
```

## Accessing the Application

### Browser Access

1. **Expose the UI service**:
   ```bash
   kubectl patch svc ui-microservice -n retail-store-dev -p '{"spec":{"type":"LoadBalancer"}}'
   ```

2. **Get the external URL**:
   ```bash
   kubectl get svc ui-microservice -n retail-store-dev
   ```

3. **Access in browser**: Use the EXTERNAL-IP from the LoadBalancer (may take a few minutes to provision)

### Port Forward (Alternative)

For immediate access without LoadBalancer:
```bash
kubectl port-forward svc/ui-microservice 8080:80 -n retail-store-dev
```
Then access: http://localhost:8080

## Troubleshooting

### Common Issues

1. **Helmfile not found**: Ensure `~/bin` is in your PATH
   ```bash
   export PATH="$HOME/bin:$PATH"
   ```

2. **Template parsing errors**: Check helmfile.yaml syntax
   ```bash
   helmfile -e dev template --skip-deps
   ```
   
   **Note**: Template parsing errors are often caused by:
   - Incorrect quote escaping in YAML
   - Missing `---` separators between sections
   - Invalid Go template syntax

3. **Missing environment variables**: Verify Terraform outputs
   ```bash
   cd environments/dev
   terraform output
   ```

4. **Missing helm-diff plugin**: Install the required plugin
   ```bash
   helm plugin install https://github.com/databus23/helm-diff
   ```

5. **Namespace ownership conflicts**: Clean up and redeploy
   ```bash
   kubectl delete namespace retail-store-dev
   ./deploy-helmfile.sh dev
   ```

6. **Pod CrashLoopBackOff**: Check pod logs for database connection issues
   ```bash
   kubectl logs -f deployment/cart-microservice -n retail-store-dev
   kubectl describe pod <pod-name> -n retail-store-dev
   ```

7. **Java applications failing with read-only filesystem**: Fixed by adding writable `/tmp` volume
   ```bash
   # If you see "Read-only file system" errors, redeploy:
   ./deploy-helmfile.sh dev
   ```

8. **Pods stuck in Pending state**: Usually due to insufficient node resources
   ```bash
   # Check node capacity:
   kubectl describe nodes | grep -A 5 "Allocated resources"
   
   # Scale down replicas or reduce resource requests in values files
   # Then redeploy:
   kubectl delete namespace retail-store-dev
   ./deploy-helmfile.sh dev
   ```

9. **CrashLoopBackOff after deployment**: Check specific service logs
   ```bash
   kubectl logs deployment/cart-microservice -n retail-store-dev
   kubectl logs deployment/catalog-microservice -n retail-store-dev
   kubectl logs deployment/order-microservice -n retail-store-dev
   ```

10. **Missing database secrets**: Ensure secrets are created properly
    ```bash
    kubectl get secrets -n retail-store-dev
    # Check if *-db-secret exists for each service
    ```

11. **Environment variable issues**: Verify Terraform outputs
    ```bash
    cd environments/dev
    terraform output database_endpoints
    terraform output secrets_manager
    ```

## Cleanup

```bash
# Remove applications
helmfile -e dev destroy

# Remove infrastructure
cd environments/dev
terraform destroy
```