# Database Connection Testing

## 🔍 Environment Variables Used by Services

### Order Service (PostgreSQL)
```yaml
RETAIL_ORDERS_PERSISTENCE_PROVIDER: "postgres"
RETAIL_ORDERS_PERSISTENCE_ENDPOINT: "postgres-host:5432"
RETAIL_ORDERS_PERSISTENCE_NAME: "orders"
RETAIL_ORDERS_PERSISTENCE_USERNAME: "postgres_user"
RETAIL_ORDERS_PERSISTENCE_PASSWORD: "postgres_password"
```

### Catalog Service (MySQL)
```yaml
RETAIL_CATALOG_PERSISTENCE_PROVIDER: "mysql"
RETAIL_CATALOG_PERSISTENCE_ENDPOINT: "mysql-host:3306"
RETAIL_CATALOG_PERSISTENCE_NAME: "catalog"
RETAIL_CATALOG_PERSISTENCE_USERNAME: "mysql_user"
RETAIL_CATALOG_PERSISTENCE_PASSWORD: "mysql_password"
```

### Cart & Checkout Services (Redis)
```yaml
RETAIL_CHECKOUT_PERSISTENCE_PROVIDER: "redis"
RETAIL_CHECKOUT_PERSISTENCE_REDIS_URL: "redis://redis-host:6379"
```

## 🧪 Test Database Connections

### 1. Check Pod Environment Variables
```bash
# Check Order service environment
kubectl exec -it deployment/order -- env | grep RETAIL_ORDERS

# Check Catalog service environment  
kubectl exec -it deployment/catalog -- env | grep RETAIL_CATALOG

# Check Checkout service environment
kubectl exec -it deployment/checkout -- env | grep RETAIL_CHECKOUT
```

### 2. Test Database Connectivity
```bash
# Test PostgreSQL connection from Order pod
kubectl exec -it deployment/order -- sh -c "nc -zv \$RETAIL_ORDERS_PERSISTENCE_ENDPOINT"

# Test MySQL connection from Catalog pod
kubectl exec -it deployment/catalog -- sh -c "nc -zv \$RETAIL_CATALOG_PERSISTENCE_ENDPOINT"

# Test Redis connection from Checkout pod
kubectl exec -it deployment/checkout -- sh -c "nc -zv redis-host 6379"
```

### 3. Check Application Health
```bash
# Check all service health endpoints
kubectl get pods
kubectl exec -it deployment/order -- curl -f http://localhost:8080/actuator/health
kubectl exec -it deployment/catalog -- curl -f http://localhost:8080/health
kubectl exec -it deployment/checkout -- curl -f http://localhost:8080/health
```

### 4. View Application Logs
```bash
# Check for database connection errors
kubectl logs deployment/order | grep -i "database\|connection\|error"
kubectl logs deployment/catalog | grep -i "mysql\|connection\|error"
kubectl logs deployment/checkout | grep -i "redis\|connection\|error"
```

## 🔧 Troubleshooting

### Common Issues:
1. **Missing Environment Variables**: Check if database credentials are properly injected
2. **Network Connectivity**: Verify security groups allow database access
3. **DNS Resolution**: Ensure database hostnames resolve correctly
4. **Authentication**: Verify username/password combinations

### Debug Commands:
```bash
# Check secrets are created
kubectl get secrets | grep -E "(postgres|mysql|redis)"

# Verify service endpoints
kubectl get svc
kubectl get endpoints

# Check ingress for UI access
kubectl get ingress
kubectl describe ingress ui
```