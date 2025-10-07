# Microservices Deployment Guide

## 🏗️ Architecture

**Generic Helm Chart**: Single reusable chart for all microservices
**Service-Specific Values**: Each microservice has its own values.yaml

```
helm-chart/                    # Generic chart
├── Chart.yaml
├── values.yaml               # Default values
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    └── hpa.yaml

microservices/                # Service-specific configurations
├── user-service/values.yaml
├── order-service/values.yaml
├── product-service/values.yaml
└── notification-service/values.yaml
```

## 🚀 Gabriel Retail Store Microservices

### Cart Service
- **Database**: DynamoDB + Redis
- **Resources**: 250m CPU, 256Mi Memory
- **Scaling**: 2-8 replicas
- **Purpose**: Shopping cart management
- **Image**: `public.ecr.aws/aws-containers/retail-store-sample-cart:1.2.4`
- **Health**: `/actuator/health`
- **Security**: Non-root user, read-only filesystem

### Catalog Service  
- **Database**: MySQL (with username, database name)
- **Resources**: 375m CPU, 384Mi Memory
- **Scaling**: 2-10 replicas
- **Purpose**: Product catalog and inventory
- **Image**: `public.ecr.aws/aws-containers/retail-store-sample-catalog:1.2.4`
- **Health**: `/health`
- **Security**: Non-root user, read-only filesystem

### Order Service
- **Database**: PostgreSQL (complete configuration)
- **Resources**: 500m CPU, 512Mi Memory  
- **Scaling**: 2-12 replicas
- **Purpose**: Order management and processing
- **Image**: `public.ecr.aws/aws-containers/retail-store-sample-orders:1.2.4`
- **Health**: `/actuator/health`
- **Security**: Non-root user, read-only filesystem

### Checkout Service
- **Database**: Redis (with proper URL format)
- **Resources**: 250m CPU, 256Mi Memory
- **Scaling**: 2-6 replicas
- **Purpose**: Checkout processing
- **Image**: `public.ecr.aws/aws-containers/retail-store-sample-checkout:1.2.4`
- **Health**: `/health`
- **Security**: Non-root user, read-only filesystem

### UI Service
- **Database**: None (Frontend)
- **Resources**: 375m CPU, 256Mi Memory
- **Scaling**: 2-8 replicas
- **Purpose**: Web frontend interface
- **Image**: `public.ecr.aws/aws-containers/retail-store-sample-ui:1.2.4`
- **Health**: `/actuator/health`
- **Ingress**: ALB with internet-facing access
- **Security**: Non-root user, read-only filesystem

## 📦 Deployment

### Automatic (GitHub Actions)
All microservices deploy automatically with:
- Database credentials from AWS Secrets Manager
- Environment-specific configurations
- Rolling updates with health checks

### Manual Deployment
```bash
# Deploy Cart Service
helm upgrade --install cart ./helm-chart \
  --namespace retail-store-dev \
  --values ./microservices/cart/values.yaml \
  --set database.redis.host=$REDIS_HOST \
  --set database.redis.password=$REDIS_PASSWORD

# Deploy Catalog Service  
helm upgrade --install catalog ./helm-chart \
  --namespace retail-store-dev \
  --values ./microservices/catalog/values.yaml \
  --set database.mysql.host=$MYSQL_HOST \
  --set database.mysql.username=$MYSQL_USERNAME \
  --set database.mysql.password=$MYSQL_PASSWORD

# Deploy Order Service
helm upgrade --install order ./helm-chart \
  --namespace retail-store-dev \
  --values ./microservices/order/values.yaml \
  --set database.postgresql.host=$POSTGRES_HOST \
  --set database.postgresql.username=$POSTGRES_USERNAME \
  --set database.postgresql.password=$POSTGRES_PASSWORD

# Deploy Checkout Service
helm upgrade --install checkout ./helm-chart \
  --namespace retail-store-dev \
  --values ./microservices/checkout/values.yaml \
  --set database.redis.host=$REDIS_HOST \
  --set database.redis.password=$REDIS_PASSWORD

# Deploy UI Service
helm upgrade --install ui ./helm-chart \
  --namespace retail-store-dev \
  --values ./microservices/ui/values.yaml
```

## 🔧 Customization

### Override Values
Create environment-specific overrides:
```yaml
# microservices/user-service/values-prod.yaml
replicaCount: 5
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
```

Deploy with overrides:
```bash
helm upgrade --install user-service ./helm-chart \
  --values ./microservices/user-service/values.yaml \
  --values ./microservices/user-service/values-prod.yaml
```

### Add New Microservice
1. Create `microservices/new-service/values.yaml`
2. Configure service-specific settings
3. Add to GitHub Actions workflow
4. Deploy with generic chart

## 🔍 Monitoring

```bash
# Check all deployments
helm list

# Check specific service
kubectl get pods -l app.kubernetes.io/name=user-service
kubectl logs -l app.kubernetes.io/name=user-service

# Check service endpoints
kubectl get svc
```