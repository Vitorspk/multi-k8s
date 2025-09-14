#!/bin/bash

# Script to wait for service dependencies to be ready

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

NAMESPACE=${NAMESPACE:-default}
TIMEOUT=${TIMEOUT:-300}

echo "=== Waiting for Service Dependencies ==="
echo "Namespace: $NAMESPACE"
echo "Timeout: ${TIMEOUT}s"
echo ""

# Using wait_for_deployment function from common.sh

# Function to check if a service has endpoints
check_service_endpoints() {
    local service=$1
    local namespace=$2
    
    endpoints=$(kubectl get endpoints "$service" -n "$namespace" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)
    if [[ -n "${endpoints}" ]]; then
        echo "  Service $service has endpoints: ${endpoints}"
        return 0
    else
        echo "  Service $service has no endpoints yet"
        return 1
    fi
}

# Function to test database connection
test_postgres_connection() {
    local namespace=$1
    
    echo -n "Testing PostgreSQL connection..."
    
    # Run a test pod to check PostgreSQL
    kubectl run postgres-test --image=postgres:15-alpine --rm -i --restart=Never -n $namespace -- \
        psql -h postgres-cluster-ip-service -U postgres -c "SELECT 1" 2>/dev/null && echo " ✓ Connected" || echo " ✗ Failed"
}

# Function to test Redis connection
test_redis_connection() {
    local namespace=$1
    
    echo -n "Testing Redis connection..."
    
    # Run a test pod to check Redis
    kubectl run redis-test --image=redis:7-alpine --rm -i --restart=Never -n $namespace -- \
        redis-cli -h redis-cluster-ip-service ping 2>/dev/null | grep -q PONG && echo " ✓ Connected" || echo " ✗ Failed"
}

# Wait for critical services
echo "=== Phase 1: Storage Services ==="

# PostgreSQL
if wait_for_deployment "postgres-deployment" "$NAMESPACE" "60"; then
    check_service_endpoints "postgres-cluster-ip-service" "$NAMESPACE"
fi

# Redis
if wait_for_deployment "redis-deployment" "$NAMESPACE" "60"; then
    check_service_endpoints "redis-cluster-ip-service" "$NAMESPACE"
fi

echo ""
echo "=== Phase 2: Application Services ==="

# Server
if wait_for_deployment "server-deployment" "$NAMESPACE" "60"; then
    check_service_endpoints "server-cluster-ip-service" "$NAMESPACE"
fi

# Worker
wait_for_deployment "worker-deployment" "$NAMESPACE" "60"

# Client
if wait_for_deployment "client-deployment" "$NAMESPACE" "60"; then
    check_service_endpoints "client-cluster-ip-service" "$NAMESPACE"
fi

echo ""
echo "=== Phase 3: Ingress ==="

# Check if ingress has an address
echo -n "Waiting for Ingress external IP..."
for i in {1..60}; do
    EXTERNAL_IP=$(kubectl get ingress ingress-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [[ -n "$EXTERNAL_IP" ]]; then
        echo " ✓ $EXTERNAL_IP"
        break
    fi
    echo -n "."
    sleep 5
done

if [[ -z "$EXTERNAL_IP" ]]; then
    echo " ✗ No external IP assigned yet"
fi

echo ""
echo "=== Deployment Status Summary ==="
kubectl get deployments -n $NAMESPACE
echo ""
kubectl get services -n $NAMESPACE
echo ""
kubectl get ingress -n $NAMESPACE

echo ""
echo "=== Health Check ==="

# Try to hit the health endpoint
if [[ -n "$EXTERNAL_IP" ]]; then
    echo "Testing application endpoint..."
    curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://$EXTERNAL_IP/ || echo "Connection failed"
    curl -s -o /dev/null -w "API Status: %{http_code}\n" http://$EXTERNAL_IP/api/ || echo "API connection failed"
fi

echo ""
echo "✓ Dependency check complete!"