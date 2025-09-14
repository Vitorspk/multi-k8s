#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Multi-K8s Project Validation ==="
echo ""

# Track errors
ERRORS=0
WARNINGS=0

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check file exists
file_exists() {
    if [[ -f "$1" ]]; then
        echo -e "${GREEN}✓${NC} $2"
        return 0
    else
        echo -e "${RED}✗${NC} $2 - File not found: $1"
        ((ERRORS++))
        return 1
    fi
}

# Function to check directory exists
dir_exists() {
    if [[ -d "$1" ]]; then
        echo -e "${GREEN}✓${NC} $2"
        return 0
    else
        echo -e "${RED}✗${NC} $2 - Directory not found: $1"
        ((ERRORS++))
        return 1
    fi
}

echo "=== Prerequisites Check ==="
echo ""

# Check required tools
echo "Checking required tools..."
if command_exists gcloud; then
    echo -e "${GREEN}✓${NC} gcloud CLI installed"
else
    echo -e "${RED}✗${NC} gcloud CLI not installed"
    ((ERRORS++))
fi

if command_exists kubectl; then
    echo -e "${GREEN}✓${NC} kubectl installed"
else
    echo -e "${RED}✗${NC} kubectl not installed"
    ((ERRORS++))
fi

if command_exists terraform; then
    echo -e "${GREEN}✓${NC} terraform installed"
else
    echo -e "${YELLOW}⚠${NC} terraform not installed (optional - GitHub Actions can handle infrastructure)"
    ((WARNINGS++))
fi

if command_exists docker; then
    echo -e "${GREEN}✓${NC} docker installed"
else
    echo -e "${RED}✗${NC} docker not installed"
    ((ERRORS++))
fi

echo ""
echo "=== Project Structure Validation ==="
echo ""

# Check directories
echo "Checking directories..."
dir_exists "client" "Client application directory"
dir_exists "server" "Server application directory"
dir_exists "worker" "Worker application directory"
dir_exists "k8s" "Kubernetes configs directory"
dir_exists "terraform" "Terraform configs directory"
dir_exists "scripts" "Scripts directory"
dir_exists ".github/workflows" "GitHub workflows directory"

echo ""
echo "Checking application files..."
# Check application files
file_exists "client/Dockerfile" "Client Dockerfile"
file_exists "client/package.json" "Client package.json"
file_exists "server/Dockerfile" "Server Dockerfile"
file_exists "server/package.json" "Server package.json"
file_exists "worker/Dockerfile" "Worker Dockerfile"
file_exists "worker/package.json" "Worker package.json"

echo ""
echo "Checking Kubernetes configs..."
# Check K8s configs
file_exists "k8s/client-config.yaml" "Client deployment"
file_exists "k8s/server-config.yaml" "Server deployment"
file_exists "k8s/worker-config.yaml" "Worker deployment"
file_exists "k8s/postgres-config.yaml" "PostgreSQL deployment"
file_exists "k8s/redis-config.yaml" "Redis deployment"
file_exists "k8s/ingress-service.yaml" "Ingress configuration"

echo ""
echo "Checking Terraform files..."
# Check Terraform files
file_exists "terraform/main.tf" "Main Terraform config"
file_exists "terraform/kubernetes.tf" "Kubernetes Terraform config"
file_exists "terraform/variables.tf" "Terraform variables"
file_exists "terraform/outputs.tf" "Terraform outputs"
file_exists "terraform/terraform.tfvars.example" "Terraform variables example"
file_exists "terraform/service-account.tf" "Service account config"

echo ""
echo "Checking scripts..."
# Check scripts
file_exists "scripts/setup-gcp-permissions.sh" "GCP permissions setup"
file_exists "scripts/setup-env-vars.sh" "Environment variables setup"
file_exists "scripts/deploy-to-gke.sh" "GKE deployment script"
file_exists "scripts/docker-build-push.sh" "Docker build script"
file_exists "scripts/validate-k8s-configs.sh" "K8s validation script"
file_exists "scripts/wait-for-dependencies.sh" "Dependencies check script"

echo ""
echo "Checking GitHub workflows..."
# Check workflows
file_exists ".github/workflows/deploy.yml" "Deploy workflow"
file_exists ".github/workflows/setup-infrastructure.yml" "Infrastructure setup workflow"
file_exists ".github/workflows/test.yml" "Test workflow"

echo ""
echo "=== Security Validation ==="
echo ""

# Check for sensitive files that shouldn't exist
echo "Checking for sensitive files..."
if [[ -f "service-account.json" ]]; then
    echo -e "${RED}✗${NC} service-account.json exists - SECURITY RISK!"
    ((ERRORS++))
else
    echo -e "${GREEN}✓${NC} No service-account.json in repository"
fi

if [[ -f "terraform/terraform.tfvars" ]]; then
    echo -e "${YELLOW}⚠${NC} terraform.tfvars exists - Make sure it's not committed"
    ((WARNINGS++))
fi

# Check .gitignore
if grep -q "service-account.json" .gitignore 2>/dev/null; then
    echo -e "${GREEN}✓${NC} service-account.json in .gitignore"
else
    echo -e "${RED}✗${NC} service-account.json not in .gitignore"
    ((ERRORS++))
fi

echo ""
echo "=== Environment Variables Check ==="
echo ""

# Check environment variables
if [[ -n "${GCP_PROJECT_ID}" ]]; then
    echo -e "${GREEN}✓${NC} GCP_PROJECT_ID is set: ${GCP_PROJECT_ID}"
else
    echo -e "${YELLOW}⚠${NC} GCP_PROJECT_ID not set"
    ((WARNINGS++))
fi

if [[ -n "${GCP_REGION}" ]]; then
    echo -e "${GREEN}✓${NC} GCP_REGION is set: ${GCP_REGION}"
else
    echo -e "${YELLOW}⚠${NC} GCP_REGION not set (will use default: southamerica-east1)"
fi

if [[ -n "${POSTGRES_PASSWORD}" ]]; then
    echo -e "${GREEN}✓${NC} POSTGRES_PASSWORD is set"
else
    echo -e "${YELLOW}⚠${NC} POSTGRES_PASSWORD not set"
    ((WARNINGS++))
fi

if [[ -n "${DOCKER_USERNAME}" ]]; then
    echo -e "${GREEN}✓${NC} DOCKER_USERNAME is set: ${DOCKER_USERNAME}"
else
    echo -e "${YELLOW}⚠${NC} DOCKER_USERNAME not set"
    ((WARNINGS++))
fi

echo ""
echo "=== Configuration Validation ==="
echo ""

# Validate K8s configs syntax (only if kubectl context is set)
if kubectl config current-context &>/dev/null; then
    echo "Validating Kubernetes YAML syntax..."
    for file in k8s/*.yaml; do
        if kubectl apply --dry-run=client -f "$file" &>/dev/null; then
            echo -e "${GREEN}✓${NC} Valid: $(basename $file)"
        else
            echo -e "${RED}✗${NC} Invalid syntax: $(basename $file)"
            ((ERRORS++))
        fi
    done
else
    echo -e "${YELLOW}⚠${NC} kubectl context not configured - skipping YAML validation"
    echo "   Run 'gcloud container clusters get-credentials' after creating cluster"
fi

echo ""
echo "=== Summary ==="
echo ""

if [[ $ERRORS -eq 0 ]]; then
    if [[ $WARNINGS -eq 0 ]]; then
        echo -e "${GREEN}✅ All validations passed!${NC}"
        echo ""
        echo "Project is ready for deployment. Next steps:"
        echo "1. Set up environment variables: ./scripts/setup-env-vars.sh"
        echo "2. Configure GCP permissions: ./scripts/setup-gcp-permissions.sh"
        echo "3. Deploy infrastructure via GitHub Actions or Terraform"
        echo "4. Deploy application: ./scripts/deploy-to-gke.sh"
    else
        echo -e "${YELLOW}⚠️  Validation completed with $WARNINGS warnings${NC}"
        echo ""
        echo "Project can be deployed but review the warnings above."
        echo "Set missing environment variables before deployment."
    fi
    exit 0
else
    echo -e "${RED}❌ Validation failed with $ERRORS errors${NC}"
    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}   Also found $WARNINGS warnings${NC}"
    fi
    echo ""
    echo "Please fix the errors above before proceeding."
    exit 1
fi