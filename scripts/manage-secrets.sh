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
    echo "🚀 Checking Secret Manager API..."

    # Check if API is already enabled
    if gcloud services list --enabled --filter="config.name:secretmanager.googleapis.com" --format="value(config.name)" --project=$PROJECT_ID | grep -q secretmanager; then
        echo "✅ Secret Manager API is already enabled"
    else
        echo "📋 Attempting to enable Secret Manager API..."
        if gcloud services enable secretmanager.googleapis.com --project=$PROJECT_ID 2>/dev/null; then
            echo "✅ Secret Manager API enabled successfully"
        else
            echo "⚠️  Failed to enable Secret Manager API automatically"
            echo "   This may require additional permissions or manual enablement."
            echo ""
            echo "   To enable manually:"
            echo "   1. Go to: https://console.cloud.google.com/apis/library/secretmanager.googleapis.com?project=$PROJECT_ID"
            echo "   2. Click 'Enable'"
            echo ""
            echo "   Or grant the service account the necessary permission:"
            echo "   gcloud projects add-iam-policy-binding $PROJECT_ID \\"
            echo "     --member=\"serviceAccount:YOUR_SA_EMAIL\" \\"
            echo "     --role=\"roles/serviceusage.serviceUsageAdmin\""
            echo ""
            echo "   Continuing with setup assuming API is or will be enabled..."
        fi
    fi
}

create_secret() {
    local secret_name=$1
    local secret_value=$2
    local description=$3

    echo "📝 Creating secret: $secret_name"

    # Check if Secret Manager is accessible
    if ! gcloud secrets list --project=$PROJECT_ID --limit=1 &>/dev/null 2>&1; then
        echo "⚠️  Secret Manager API is not accessible yet"
        echo "   Secret $secret_name will need to be created after API is enabled"
        return 1
    fi

    if gcloud secrets describe $secret_name --project=$PROJECT_ID &>/dev/null 2>&1; then
        echo "⚠️  Secret $secret_name already exists. Adding new version..."
        if echo -n "$secret_value" | gcloud secrets versions add $secret_name --data-file=- --project=$PROJECT_ID 2>/dev/null; then
            echo "✅ Secret $secret_name updated successfully"
        else
            echo "❌ Failed to update secret $secret_name"
            return 1
        fi
    else
        echo "🆕 Creating new secret: $secret_name"
        if echo -n "$secret_value" | gcloud secrets create $secret_name --data-file=- --project=$PROJECT_ID 2>/dev/null; then
            echo "✅ Secret $secret_name created successfully"
        else
            echo "❌ Failed to create secret $secret_name"
            return 1
        fi
    fi

    return 0
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

    local failed_count=0

    # Database secrets (with environment variable fallbacks)
    create_secret "postgres-password" "${POSTGRES_PASSWORD:-mypassword123}" "PostgreSQL database password" || ((failed_count++))
    create_secret "postgres-user" "${POSTGRES_USER:-postgres}" "PostgreSQL database username" || ((failed_count++))
    create_secret "postgres-host" "${POSTGRES_HOST:-postgres-cluster-ip-service}" "PostgreSQL database host" || ((failed_count++))
    create_secret "postgres-port" "${POSTGRES_PORT:-5432}" "PostgreSQL database port" || ((failed_count++))
    create_secret "postgres-database" "${POSTGRES_DATABASE:-postgres}" "PostgreSQL database name" || ((failed_count++))

    # Redis secrets (with environment variable fallbacks)
    create_secret "redis-host" "${REDIS_HOST:-redis-cluster-ip-service}" "Redis host" || ((failed_count++))
    create_secret "redis-port" "${REDIS_PORT:-6379}" "Redis port" || ((failed_count++))

    if [ $failed_count -eq 0 ]; then
        echo "✅ All secrets created successfully"
    else
        echo "⚠️  $failed_count secrets failed to create"
        echo "   Please enable the Secret Manager API and run this script again"
        return 1
    fi
}

list_secrets() {
    echo "📋 Listing all secrets:"
    if gcloud secrets list --project=$PROJECT_ID --format="table(name:label=SECRET_NAME,createTime:label=CREATED)" 2>/dev/null; then
        return 0
    else
        echo "⚠️  Unable to list secrets (Secret Manager API may not be enabled)"
        return 1
    fi
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

            # Try to setup secrets, but don't fail completely if API is not ready
            if setup_secrets; then
                grant_k8s_access
                list_secrets
            else
                echo ""
                echo "⚠️  Secret Manager setup incomplete"
                echo ""
                echo "Next steps:"
                echo "1. Enable the Secret Manager API manually:"
                echo "   https://console.cloud.google.com/apis/library/secretmanager.googleapis.com?project=$PROJECT_ID"
                echo ""
                echo "2. Re-run this script after API is enabled:"
                echo "   ./scripts/manage-secrets.sh setup"
                echo ""
                echo "3. Or grant the service account permission to enable APIs:"
                echo "   gcloud projects add-iam-policy-binding $PROJECT_ID \\"
                echo "     --member=\"serviceAccount:multi-k8s-deployer@$PROJECT_ID.iam.gserviceaccount.com\" \\"
                echo "     --role=\"roles/serviceusage.serviceUsageAdmin\""
            fi
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