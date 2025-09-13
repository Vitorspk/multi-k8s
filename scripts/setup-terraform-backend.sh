#!/bin/bash

# Script to create the GCS bucket for Terraform state storage
# This needs to be run once before using Terraform

set -e

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-vschiavo-home}"
BUCKET_NAME="vschiavo-home-terraform-state"
REGION="${GCP_REGION:-southamerica-east1}"

echo "🚀 Setting up Terraform backend bucket..."
echo "   Project: $PROJECT_ID"
echo "   Bucket: $BUCKET_NAME"
echo "   Region: $REGION"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI is not installed. Please install it first."
    exit 1
fi

# Check if authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo "❌ Not authenticated with gcloud. Please run 'gcloud auth login' first."
    exit 1
fi

# Set the project
echo "📦 Setting project to $PROJECT_ID..."
gcloud config set project $PROJECT_ID

# Check if bucket exists
if gsutil ls -b gs://$BUCKET_NAME &> /dev/null; then
    echo "✅ Bucket gs://$BUCKET_NAME already exists"
else
    echo "📦 Creating bucket gs://$BUCKET_NAME..."
    if ! gsutil mb -p $PROJECT_ID -l $REGION gs://$BUCKET_NAME 2>/dev/null; then
        echo ""
        echo "❌ Failed to create bucket. This could be due to:"
        echo "   1. Insufficient permissions (need storage.buckets.create)"
        echo "   2. The bucket name is already taken globally"
        echo ""
        echo "🔧 To fix this, either:"
        echo "   1. Run with an account that has Storage Admin role:"
        echo "      gcloud auth login"
        echo "      ./scripts/setup-terraform-backend.sh"
        echo ""
        echo "   2. Or create the bucket manually in the GCP Console:"
        echo "      - Go to https://console.cloud.google.com/storage"
        echo "      - Create bucket: $BUCKET_NAME"
        echo "      - Location: $REGION"
        echo "      - Enable versioning"
        echo ""
        echo "   3. Or use GitHub Actions workflow:"
        echo "      - Go to Actions tab"
        echo "      - Run 'Setup GKE Infrastructure' workflow"
        exit 1
    fi
    
    # Enable versioning for state file history
    echo "🔄 Enabling versioning on bucket..."
    gsutil versioning set on gs://$BUCKET_NAME
    
    # Set lifecycle rule to delete old versions after 30 days
    echo "⏰ Setting lifecycle rules..."
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
    gsutil lifecycle set /tmp/lifecycle.json gs://$BUCKET_NAME
    rm /tmp/lifecycle.json
    
    echo "✅ Bucket created successfully!"
fi

echo ""
echo "🎉 Terraform backend is ready!"
echo "   You can now run 'terraform init' in the terraform directory"