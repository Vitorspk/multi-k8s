#!/bin/bash

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

PROJECT_ID=${PROJECT_ID:-"vschiavo-home"}
REGION=${REGION:-"southamerica-east1"}

print_info "🔐 Managing secrets for project: $PROJECT_ID"

check_prerequisites() {
    echo "🔍 Checking prerequisites..."

    if ! command -v gcloud &> /dev/null; then
        echo "❌ gcloud CLI not found. Please install it first."
        exit 1
    fi

    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 > /dev/null; then
        echo "❌ Not authenticated with gcloud. Please run 'gcloud auth login'"
        exit 1
    fi

    echo "✅ Prerequisites check passed"
}

enable_secret_manager_api() {
    echo "🚀 Enabling Secret Manager API..."
    gcloud services enable secretmanager.googleapis.com --project=$PROJECT_ID
    echo "✅ Secret Manager API enabled"
}

create_secret() {
    local secret_name=$1
    local secret_value=$2
    local description=$3

    echo "📝 Creating secret: $secret_name"

    if gcloud secrets describe $secret_name --project=$PROJECT_ID &>/dev/null; then
        echo "⚠️  Secret $secret_name already exists. Adding new version..."
        echo -n "$secret_value" | gcloud secrets versions add $secret_name --data-file=- --project=$PROJECT_ID
    else
        echo "🆕 Creating new secret: $secret_name"
        # Create secret without description (GCP Secret Manager doesn't support --set-description)
        echo -n "$secret_value" | gcloud secrets create $secret_name --data-file=- --project=$PROJECT_ID
    fi

    echo "✅ Secret $secret_name created/updated successfully"
}

load_env_file() {
    # Load environment variables from .env.local if it exists
    if [ -f ".env.local" ]; then
        echo "📄 Loading environment variables from .env.local"
        export $(grep -v '^#' .env.local | xargs)
    fi
}

setup_secrets() {
    echo "🔧 Setting up application secrets..."

    load_env_file

    # Database secrets (with environment variable fallbacks)
    create_secret "postgres-password" "${POSTGRES_PASSWORD:-mypassword123}" "PostgreSQL database password"
    create_secret "postgres-user" "${POSTGRES_USER:-postgres}" "PostgreSQL database username"
    create_secret "postgres-host" "${POSTGRES_HOST:-postgres-cluster-ip-service}" "PostgreSQL database host"
    create_secret "postgres-port" "${POSTGRES_PORT:-5432}" "PostgreSQL database port"
    create_secret "postgres-database" "${POSTGRES_DATABASE:-postgres}" "PostgreSQL database name"

    # Redis secrets (with environment variable fallbacks)
    create_secret "redis-host" "${REDIS_HOST:-redis-cluster-ip-service}" "Redis host"
    create_secret "redis-port" "${REDIS_PORT:-6379}" "Redis port"

    echo "✅ All secrets created successfully"
}

list_secrets() {
    echo "📋 Listing all secrets:"
    gcloud secrets list --project=$PROJECT_ID --format="table(name:label=SECRET_NAME,createTime:label=CREATED)"
}

grant_k8s_access() {
    echo "🔐 Setting up Kubernetes access to secrets..."

    # Get the correct service account email
    local k8s_service_account="multi-k8s-deployer@$PROJECT_ID.iam.gserviceaccount.com"

    # Check if service account exists
    if gcloud iam service-accounts describe $k8s_service_account --project=$PROJECT_ID &>/dev/null; then
        # Grant Secret Manager Secret Accessor role
        gcloud projects add-iam-policy-binding $PROJECT_ID \
            --member="serviceAccount:$k8s_service_account" \
            --role="roles/secretmanager.secretAccessor"

        echo "✅ Kubernetes service account granted access to secrets"
    else
        echo "⚠️  Service account $k8s_service_account not found. You may need to grant permissions manually."
        echo "   Run: gcloud projects add-iam-policy-binding $PROJECT_ID \\"
        echo "        --member=\"serviceAccount:YOUR_SA_EMAIL\" \\"
        echo "        --role=\"roles/secretmanager.secretAccessor\""
    fi
}

main() {
    case "${1:-setup}" in
        "setup")
            check_prerequisites
            enable_secret_manager_api
            setup_secrets
            grant_k8s_access
            list_secrets
            ;;
        "list")
            list_secrets
            ;;
        "create")
            if [ -z "$2" ] || [ -z "$3" ]; then
                echo "❌ Usage: $0 create SECRET_NAME SECRET_VALUE [DESCRIPTION]"
                exit 1
            fi
            create_secret "$2" "$3" "$4"
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [COMMAND]"
            echo ""
            echo "Commands:"
            echo "  setup     Setup all application secrets (default)"
            echo "  list      List all secrets"
            echo "  create    Create a single secret"
            echo "  help      Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  PROJECT_ID: GCP project ID (default: vschiavo-home)"
            echo "  REGION: GCP region (default: southamerica-east1)"
            ;;
        *)
            echo "❌ Unknown command: $1"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"