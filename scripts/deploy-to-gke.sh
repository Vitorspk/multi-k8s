#!/bin/bash

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

echo "=== Deploy to GKE ==="
echo ""

# Validate required environment variables
ERRORS=0
validate_env_var "GCP_PROJECT_ID" true || ((ERRORS++))
validate_env_var "POSTGRES_PASSWORD" true || ((ERRORS++))
validate_env_var "GCP_REGION" false
validate_env_var "GCP_ZONE" false

if [[ $ERRORS -gt 0 ]]; then
    echo ""
    print_error "Missing required environment variables"
    echo "Usage:"
    echo "  export GCP_PROJECT_ID='your-gcp-project-id'"
    echo "  export POSTGRES_PASSWORD='your-secure-password'"
    exit 1
fi

# Set defaults
PROJECT_ID="${GCP_PROJECT_ID}"
REGION="${GCP_REGION:-$DEFAULT_GCP_REGION}"
ZONE="${GCP_ZONE:-$DEFAULT_GCP_ZONE}"
CLUSTER_NAME="${CLUSTER_NAME:-$DEFAULT_CLUSTER_NAME}"

echo ""
echo "Configuration:"
echo "  Project: ${PROJECT_ID}"
echo "  Region: ${REGION}"
echo "  Zone: ${ZONE}"
echo "  Cluster: ${CLUSTER_NAME}"
echo ""

# Configure GCP project
echo "1. Configuring GCP project..."
if ! gcloud config set project "$PROJECT_ID"; then
    print_error "Failed to set GCP project. Check if project exists and you have access."
    exit 1
fi

# Check if cluster exists
echo ""
echo "2. Checking cluster..."
if ! check_cluster_exists "$CLUSTER_NAME" "$ZONE" "$PROJECT_ID"; then
    print_error "Cluster '$CLUSTER_NAME' does not exist in zone '$ZONE'"
    echo ""
    echo "Please create the infrastructure first:"
    echo "  Option 1: Use GitHub Actions - Setup GKE Infrastructure workflow"
    echo "  Option 2: cd terraform && terraform apply"
    exit 1
fi
print_success "Cluster exists"

# Get cluster credentials
echo ""
echo "3. Getting cluster credentials..."
if ! get_cluster_credentials "$CLUSTER_NAME" "$ZONE" "$PROJECT_ID"; then
    exit 1
fi

# Create PostgreSQL secret
echo ""
echo "4. Creating PostgreSQL secret..."
if ! create_postgres_secret "$POSTGRES_PASSWORD"; then
    exit 1
fi

# Install NGINX Ingress Controller
echo ""
echo "5. Setting up NGINX Ingress Controller..."
if kubectl get namespace ingress-nginx &>/dev/null; then
    print_info "NGINX Ingress namespace already exists"
else
    echo "Installing NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
    
    # Wait for controller to be ready
    echo "Waiting for NGINX Ingress Controller..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s || print_warning "Controller may still be starting"
fi

# Apply Kubernetes configurations
echo ""
echo "6. Applying Kubernetes configurations..."
if kubectl apply -f k8s/; then
    print_success "Kubernetes configurations applied"
else
    print_error "Failed to apply some configurations"
    exit 1
fi

# Check deployment status
echo ""
echo "7. Checking deployments..."
wait_for_deployment "client-deployment" "default" 120
wait_for_deployment "server-deployment" "default" 120
wait_for_deployment "worker-deployment" "default" 120
wait_for_deployment "postgres-deployment" "default" 120
wait_for_deployment "redis-deployment" "default" 120

# Get external IP
echo ""
echo "8. Getting Load Balancer IP..."
if get_external_ip "ingress-nginx-controller" "ingress-nginx" 60; then
    echo ""
    echo "✅ Deployment completed successfully!"
    echo ""
    echo "📊 Status:"
    kubectl get deployments
    echo ""
    kubectl get services
    echo ""
    kubectl get ingress
    echo ""
    echo "🌐 Access the application at: http://$EXTERNAL_IP"
    echo ""
    echo "💡 Useful commands:"
    echo "  View logs: kubectl logs deployment/[deployment-name]"
    echo "  View pods: kubectl get pods"
    echo "  Scale: kubectl scale deployment/[name] --replicas=3"
else
    print_warning "Application deployed but external IP not yet available"
    echo "Check later with: kubectl get service ingress-nginx-controller -n ingress-nginx"
fi