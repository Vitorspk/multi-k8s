#!/bin/bash

# Common functions and utilities for multi-k8s scripts

# Colors for output
export GREEN='\033[0;32m'
export RED='\033[0;31m'
export YELLOW='\033[1;33m'
export NC='\033[0m' # No Color

# Default values
export DEFAULT_GCP_REGION="southamerica-east1"
export DEFAULT_GCP_ZONE="southamerica-east1-a"
export DEFAULT_CLUSTER_NAME="multi-k8s-cluster"
export DEFAULT_BUCKET_SUFFIX="terraform-state"

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "ℹ️  $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate environment variables
validate_env_var() {
    local var_name=$1
    local var_value=${!var_name}
    local required=${2:-false}
    
    if [[ -z "$var_value" ]]; then
        if [[ "$required" == "true" ]]; then
            print_error "$var_name is not set (required)"
            return 1
        else
            print_warning "$var_name is not set (optional)"
            return 0
        fi
    else
        print_success "$var_name is set"
        return 0
    fi
}

# Function to check GKE cluster exists
check_cluster_exists() {
    local cluster_name=${1:-$DEFAULT_CLUSTER_NAME}
    local zone=${2:-$DEFAULT_GCP_ZONE}
    local project_id=${3:-$GCP_PROJECT_ID}
    
    if gcloud container clusters describe "$cluster_name" \
        --zone="$zone" \
        --project="$project_id" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to get cluster credentials
get_cluster_credentials() {
    local cluster_name=${1:-$DEFAULT_CLUSTER_NAME}
    local zone=${2:-$DEFAULT_GCP_ZONE}
    local project_id=${3:-$GCP_PROJECT_ID}
    
    echo "Getting credentials for cluster $cluster_name..."
    if gcloud container clusters get-credentials "$cluster_name" \
        --zone="$zone" \
        --project="$project_id"; then
        print_success "Cluster credentials configured"
        return 0
    else
        print_error "Failed to get cluster credentials"
        return 1
    fi
}

# Function to create PostgreSQL secret
create_postgres_secret() {
    local password=${1:-$POSTGRES_PASSWORD}
    local namespace=${2:-default}
    
    if [[ -z "$password" ]]; then
        print_error "PostgreSQL password not provided"
        return 1
    fi
    
    if kubectl get secret pgpassword -n "$namespace" &>/dev/null; then
        print_info "PostgreSQL secret already exists"
        return 0
    else
        echo "Creating PostgreSQL secret..."
        if kubectl create secret generic pgpassword \
            --from-literal=PGPASSWORD="$password" \
            -n "$namespace"; then
            print_success "PostgreSQL secret created"
            return 0
        else
            print_error "Failed to create PostgreSQL secret"
            return 1
        fi
    fi
}

# Function to check if bucket exists
bucket_exists() {
    local bucket_name=$1
    gsutil ls -b "gs://$bucket_name" &>/dev/null
}

# Function to create GCS bucket with versioning
create_gcs_bucket() {
    local bucket_name=$1
    local project_id=${2:-$GCP_PROJECT_ID}
    local region=${3:-$DEFAULT_GCP_REGION}
    
    if bucket_exists "$bucket_name"; then
        print_info "Bucket gs://$bucket_name already exists"
        return 0
    fi
    
    echo "Creating bucket gs://$bucket_name..."
    if gsutil mb -p "$project_id" -l "$region" "gs://$bucket_name"; then
        # Enable versioning
        gsutil versioning set on "gs://$bucket_name"
        
        # Set lifecycle rule
        cat > /tmp/lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "age": 30,
          "isLive": false
        }
      }
    ]
  }
}
EOF
        gsutil lifecycle set /tmp/lifecycle.json "gs://$bucket_name"
        rm /tmp/lifecycle.json
        
        print_success "Bucket created with versioning and lifecycle rules"
        return 0
    else
        print_error "Failed to create bucket"
        return 1
    fi
}

# Function to wait for deployment
wait_for_deployment() {
    local deployment=$1
    local namespace=${2:-default}
    local timeout=${3:-60}
    
    echo -n "Waiting for $deployment..."
    if kubectl wait --for=condition=available \
        --timeout="${timeout}s" \
        deployment/"$deployment" \
        -n "$namespace" 2>/dev/null; then
        print_success "Ready"
        return 0
    else
        print_error "Failed or timed out"
        return 1
    fi
}

# Function to get external IP
get_external_ip() {
    local service_name=${1:-ingress-nginx-controller}
    local namespace=${2:-ingress-nginx}
    local max_attempts=${3:-60}
    
    echo -n "Waiting for external IP"
    for i in $(seq 1 $max_attempts); do
        EXTERNAL_IP=$(kubectl get service "$service_name" \
            -n "$namespace" \
            -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        
        if [[ -n "$EXTERNAL_IP" ]]; then
            echo ""
            print_success "External IP: $EXTERNAL_IP"
            export EXTERNAL_IP
            return 0
        fi
        echo -n "."
        sleep 2
    done
    
    echo ""
    print_error "No external IP assigned"
    return 1
}