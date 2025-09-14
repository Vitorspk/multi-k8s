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






# Function to check if bucket exists
bucket_exists() {
    local bucket_name=$1
    gsutil ls -b "gs://$bucket_name" &>/dev/null
}

# Function to create GCS bucket with versioning
# Note: Similar logic exists in .github/workflows/setup-infrastructure.yml
# Kept here for local script usage in setup-gcp-permissions.sh
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

