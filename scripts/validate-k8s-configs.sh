#!/bin/bash

echo "=== Validating Kubernetes Configurations ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Track if any errors found
ERRORS_FOUND=0

# Function to check if a deployment has required fields
check_deployment() {
    local file=$1
    echo "Checking $file..."
    
    # Check for resource limits
    if grep -q "resources:" "$file" && grep -q "limits:" "$file" && grep -q "requests:" "$file"; then
        echo -e "${GREEN}✓${NC} Resource limits configured"
    else
        echo -e "${RED}✗${NC} Missing resource limits"
        ERRORS_FOUND=1
    fi
    
    # Check for health checks (not applicable for postgres and redis as they have exec probes)
    if [[ "$file" == *"server-config"* ]] || [[ "$file" == *"client-config"* ]]; then
        if grep -q "livenessProbe:" "$file" && grep -q "readinessProbe:" "$file"; then
            echo -e "${GREEN}✓${NC} Health checks configured"
        else
            echo -e "${RED}✗${NC} Missing health checks"
            ERRORS_FOUND=1
        fi
    fi
    
    # Check for image tags (recommend using specific tags instead of latest)
    if grep -E "image:.*:latest" "$file" > /dev/null; then
        echo -e "${RED}⚠${NC} Warning: Using 'latest' tag for images (consider using specific versions)"
    fi
    
    echo ""
}

# Check each deployment file
for file in k8s/*-config.yaml; do
    if [[ -f "$file" ]]; then
        check_deployment "$file"
    fi
done

# Check if PostgreSQL has proper environment variables
echo "Checking PostgreSQL configuration..."
if grep -q "POSTGRES_PASSWORD" k8s/postgres-config.yaml && \
   grep -q "POSTGRES_DB" k8s/postgres-config.yaml && \
   grep -q "POSTGRES_USER" k8s/postgres-config.yaml; then
    echo -e "${GREEN}✓${NC} PostgreSQL environment variables properly configured"
else
    echo -e "${RED}✗${NC} PostgreSQL missing required environment variables"
    ERRORS_FOUND=1
fi
echo ""

# Check ingress configuration
echo "Checking Ingress configuration..."
if [[ -f "k8s/ingress-service.yaml" ]]; then
    if grep -q "nginx.ingress.kubernetes.io/rewrite-target" k8s/ingress-service.yaml; then
        echo -e "${GREEN}✓${NC} Ingress rewrite rules configured"
    else
        echo -e "${RED}✗${NC} Missing ingress rewrite rules"
        ERRORS_FOUND=1
    fi
fi
echo ""

# Summary
echo "=== Validation Summary ==="
if [[ $ERRORS_FOUND -eq 0 ]]; then
    echo -e "${GREEN}✓ All critical configurations are in place!${NC}"
    echo ""
    echo "Ready for deployment. Use the following command to deploy:"
    echo "  ./scripts/deploy-to-gke.sh"
else
    echo -e "${RED}✗ Some issues found. Please review the errors above.${NC}"
    exit 1
fi

echo ""
echo "=== Resource Summary ==="
echo "Deployments to be created:"
echo "  - PostgreSQL (1 replica, 256Mi-512Mi memory)"
echo "  - Redis (1 replica, 64Mi-128Mi memory)"
echo "  - Server (3 replicas, 128Mi-256Mi memory each)"
echo "  - Worker (1 replica, 128Mi-256Mi memory)"
echo "  - Client (3 replicas, 64Mi-128Mi memory each)"
echo ""
echo "Total estimated memory requirements:"
echo "  Minimum: ~900Mi"
echo "  Maximum: ~1.8Gi"