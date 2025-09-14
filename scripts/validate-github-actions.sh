#!/bin/bash

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

echo "=== GitHub Actions Validation ==="
echo ""
echo "This script validates that everything is ready for GitHub Actions deployment"
echo ""

ERRORS=0
WARNINGS=0

# Required secrets for GitHub Actions
echo "📋 Required GitHub Secrets:"
echo ""
echo "These secrets MUST be configured in your GitHub repository:"
echo "  Settings > Secrets and variables > Actions > New repository secret"
echo ""

REQUIRED_SECRETS=(
    "GCP_PROJECT_ID|Your Google Cloud Project ID (e.g., my-project-123)"
    "GCP_SA_KEY|Service account JSON key (run: cat service-account.json)"
    "DOCKER_USERNAME|Your Docker Hub username"
    "DOCKER_PASSWORD|Your Docker Hub password or access token"
    "POSTGRES_PASSWORD|A secure password for PostgreSQL"
)

echo "Required secrets:"
for secret in "${REQUIRED_SECRETS[@]}"; do
    IFS='|' read -r name description <<< "$secret"
    echo "  ✓ $name - $description"
done

echo ""
echo "Optional secrets (have defaults):"
echo "  ○ GKE_CLUSTER_NAME - Default: multi-k8s-cluster"
echo "  ○ GKE_ZONE - Default: southamerica-east1-a"
echo "  ○ DEPLOYMENT_NAME - Default: multi-k8s"

echo ""
echo "=== Pre-flight Checks ==="
echo ""

# Check if service account file exists locally
echo "1. Checking service account key..."
if [[ -f "service-account.json" ]]; then
    print_success "service-account.json exists locally"
    echo "   Copy to GitHub Secrets: cat service-account.json | pbcopy"
else
    print_error "service-account.json not found"
    echo "   Run: ./scripts/setup-gcp-permissions.sh"
    ((ERRORS++))
fi

# Check workflow files
echo ""
echo "2. Checking GitHub Actions workflows..."
if [[ -f ".github/workflows/setup-infrastructure.yml" ]]; then
    print_success "Infrastructure setup workflow exists"
else
    print_error "setup-infrastructure.yml not found"
    ((ERRORS++))
fi

if [[ -f ".github/workflows/deploy.yml" ]]; then
    print_success "Deploy workflow exists"
else
    print_error "deploy.yml not found"
    ((ERRORS++))
fi

if [[ -f ".github/workflows/test.yml" ]]; then
    print_success "Test workflow exists"
else
    print_error "test.yml not found"
    ((ERRORS++))
fi

# Check Terraform configuration
echo ""
echo "3. Checking Terraform configuration..."
if [[ -f "terraform/main.tf" ]]; then
    print_success "Terraform main configuration exists"
else
    print_error "terraform/main.tf not found"
    ((ERRORS++))
fi

if [[ -f "terraform/variables.tf" ]]; then
    print_success "Terraform variables defined"
else
    print_error "terraform/variables.tf not found"
    ((ERRORS++))
fi

if [[ -f "terraform/terraform.tfvars.example" ]]; then
    print_success "Terraform example variables exist"
else
    print_error "terraform/terraform.tfvars.example not found"
    ((ERRORS++))
fi

# Check Kubernetes configurations
echo ""
echo "4. Checking Kubernetes configurations..."
K8S_FILES=(
    "client-config.yaml"
    "server-config.yaml"
    "worker-config.yaml"
    "postgres-config.yaml"
    "redis-config.yaml"
    "ingress-service.yaml"
)

for file in "${K8S_FILES[@]}"; do
    if [[ -f "k8s/$file" ]]; then
        print_success "$file exists"
    else
        print_error "$file not found"
        ((ERRORS++))
    fi
done

# Check Docker configurations
echo ""
echo "5. Checking Docker configurations..."
DOCKERFILES=(
    "client/Dockerfile"
    "server/Dockerfile"
    "worker/Dockerfile"
)

for dockerfile in "${DOCKERFILES[@]}"; do
    if [[ -f "$dockerfile" ]]; then
        print_success "$dockerfile exists"
    else
        print_error "$dockerfile not found"
        ((ERRORS++))
    fi
done

# Check .gitignore
echo ""
echo "6. Checking security (.gitignore)..."
if grep -q "service-account.json" .gitignore 2>/dev/null; then
    print_success "service-account.json in .gitignore"
else
    print_error "service-account.json not in .gitignore - SECURITY RISK!"
    ((ERRORS++))
fi

if grep -q "terraform.tfvars" .gitignore 2>/dev/null; then
    print_success "terraform.tfvars in .gitignore"
else
    print_warning "terraform.tfvars not in .gitignore"
    ((WARNINGS++))
fi

echo ""
echo "=== Workflow Execution Order ==="
echo ""
echo "After configuring all secrets, execute in this order:"
echo ""
echo "1️⃣  Setup Infrastructure (run once):"
echo "    - Go to GitHub Actions tab"
echo "    - Select 'Setup GKE Infrastructure'"
echo "    - Click 'Run workflow' > Select 'apply' > Run"
echo "    - Wait ~10-15 minutes for completion"
echo ""
echo "2️⃣  Deploy Application (automatic on push to main/master):"
echo "    - Make any change and push to main/master branch"
echo "    - Or manually trigger 'Deploy to GKE' workflow"
echo ""
echo "3️⃣  Verify Deployment:"
echo "    - Check Actions tab for green checkmarks"
echo "    - Get external IP from workflow logs"
echo "    - Access application at http://<EXTERNAL_IP>"

echo ""
echo "=== Summary ==="
echo ""

if [[ $ERRORS -eq 0 ]]; then
    if [[ $WARNINGS -eq 0 ]]; then
        echo -e "${GREEN}✅ All GitHub Actions validations passed!${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Add all required secrets to GitHub repository"
        echo "2. Run 'Setup GKE Infrastructure' workflow"
        echo "3. Push code to trigger deployment"
    else
        echo -e "${YELLOW}⚠️  Validation completed with $WARNINGS warnings${NC}"
        echo ""
        echo "GitHub Actions will work but review warnings above."
    fi
else
    echo -e "${RED}❌ Validation failed with $ERRORS errors${NC}"
    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}   Also found $WARNINGS warnings${NC}"
    fi
    echo ""
    echo "Fix the errors above before running GitHub Actions."
    echo ""
    echo "Quick fix:"
    echo "1. Run: ./scripts/setup-gcp-permissions.sh"
    echo "2. Copy service account key to GitHub Secrets"
    echo "3. Re-run this validation"
fi

echo ""
echo "📚 Documentation: Check README.md for detailed instructions"