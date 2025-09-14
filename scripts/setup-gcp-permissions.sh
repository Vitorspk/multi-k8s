#!/usr/bin/env bash

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-vschiavo-home}"
REGION="${GCP_REGION:-$DEFAULT_GCP_REGION}"
SERVICE_ACCOUNT_NAME="multi-k8s-deployer"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
BUCKET_NAME="${PROJECT_ID}-${DEFAULT_BUCKET_SUFFIX}"

echo "=== GCP Permissions Setup ==="
echo ""
echo "Configuration:"
echo "  Project: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Service Account: $SERVICE_ACCOUNT_EMAIL"
echo "  Terraform Bucket: gs://$BUCKET_NAME"
echo ""

# Check if service account exists
echo "1. Checking service account..."
if ! gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" --project="$PROJECT_ID" &>/dev/null; then
    echo "Creating service account..."
    gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
        --display-name="Multi-K8s Deployer" \
        --description="Service account for GitHub Actions deployments" \
        --project="$PROJECT_ID"
    print_success "Service account created"
else
    print_info "Service account already exists"
fi

# Grant necessary roles
echo ""
echo "2. Granting IAM roles..."
ROLES=(
    "roles/storage.admin"
    "roles/artifactregistry.writer"
    "roles/container.admin"
    "roles/compute.admin"
    "roles/iam.serviceAccountUser"
    "roles/resourcemanager.projectIamAdmin"
    "roles/serviceusage.serviceUsageAdmin"
    "roles/secretmanager.admin"
)

for role in "${ROLES[@]}"; do
    echo "   Granting $role..."
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
        --role="$role" \
        --condition=None \
        --quiet
done
print_success "All roles granted"

# Create service account key
echo ""
echo "3. Creating service account key..."
if [[ -f "service-account.json" ]]; then
    print_warning "service-account.json already exists"
    read -p "Overwrite existing key? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing key"
    else
        gcloud iam service-accounts keys create service-account.json \
            --iam-account="$SERVICE_ACCOUNT_EMAIL" \
            --project="$PROJECT_ID"
        print_success "New key created"
    fi
else
    gcloud iam service-accounts keys create service-account.json \
        --iam-account="$SERVICE_ACCOUNT_EMAIL" \
        --project="$PROJECT_ID"
    print_success "Service account key created"
fi

# Create Terraform backend bucket if requested
echo ""
read -p "Do you want to create the Terraform backend bucket? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "4. Creating Terraform backend bucket..."
    if create_gcs_bucket "$BUCKET_NAME" "$PROJECT_ID" "$REGION"; then
        print_success "Terraform backend ready"
    else
        print_warning "Failed to create bucket. You can create it manually or via GitHub Actions."
    fi
else
    echo "Skipping bucket creation"
fi

# Summary
echo ""
echo "✅ Setup complete!"
echo ""
echo "Service account configured with the following roles:"
for role in "${ROLES[@]}"; do
    echo "  - $role"
done
echo ""
echo "Service account key saved to: service-account.json"
echo ""
echo "⚠️  IMPORTANT NEXT STEPS:"
echo ""
echo "1. Add the service account key to GitHub Secrets:"
echo "   cat service-account.json | pbcopy"
echo "   Then paste in: GitHub Settings > Secrets > Actions > GCP_SA_KEY"
echo ""
echo "2. Ensure service-account.json is in .gitignore (security!)"
echo ""
echo "3. Run the infrastructure setup:"
echo "   - Via GitHub Actions: Actions > Setup GKE Infrastructure > Run workflow"
echo "   - Or locally: cd terraform && terraform init && terraform apply"