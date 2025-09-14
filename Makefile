# Multi-K8s Project Makefile

# Variables
PROJECT_ID ?= vschiavo-home
CLUSTER_NAME ?= multi-k8s-cluster
ZONE ?= southamerica-east1-a

.PHONY: help secrets-setup secrets-sync secrets-list secrets-validate deploy-local test clean

help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Secret Management
secrets-setup: ## Setup all secrets in GCP Secret Manager
	@echo "🔐 Setting up secrets in GCP Secret Manager..."
	@chmod +x scripts/manage-secrets.sh
	@PROJECT_ID=$(PROJECT_ID) scripts/manage-secrets.sh setup

secrets-sync: ## Sync secrets from Secret Manager to Kubernetes
	@echo "🔄 Syncing secrets from Secret Manager to Kubernetes..."
	@python3 scripts/sync-secrets.py --project-id=$(PROJECT_ID)

secrets-list: ## List all secrets in Secret Manager
	@echo "📋 Listing secrets in Secret Manager..."
	@PROJECT_ID=$(PROJECT_ID) scripts/manage-secrets.sh list

secrets-validate: ## Validate all required secrets exist
	@echo "✅ Validating secrets..."
	@python3 scripts/sync-secrets.py --project-id=$(PROJECT_ID) --validate-only

# Kubernetes Operations
deploy-local: secrets-sync ## Deploy to local/current Kubernetes context
	@echo "🚀 Deploying to Kubernetes..."
	@kubectl apply -f k8s/
	@kubectl rollout status deployment/client-deployment --timeout=300s
	@kubectl rollout status deployment/server-deployment --timeout=300s
	@kubectl rollout status deployment/worker-deployment --timeout=300s
	@echo "✅ Deployment completed!"

k8s-status: ## Show Kubernetes deployment status
	@echo "📊 Kubernetes Status:"
	@kubectl get pods,services,secrets | grep -E "(NAME|multi-|database-|redis-|pgpassword)"

k8s-logs-server: ## Show server logs
	@kubectl logs -l component=server --tail=50

k8s-logs-worker: ## Show worker logs
	@kubectl logs -l component=worker --tail=50

k8s-clean: ## Delete all Kubernetes resources
	@echo "🧹 Cleaning up Kubernetes resources..."
	@kubectl delete -f k8s/ --ignore-not-found=true
	@kubectl delete secret database-secrets redis-secrets pgpassword --ignore-not-found=true

# Development
test: ## Run tests (if available)
	@echo "🧪 Running tests..."
	@if [ -f "package.json" ]; then npm test; fi

clean: k8s-clean ## Clean up all resources
	@echo "🧹 Cleanup completed!"

# GCP Operations
gcp-login: ## Login to GCP
	@gcloud auth login
	@gcloud config set project $(PROJECT_ID)

gcp-cluster-credentials: ## Get GKE cluster credentials
	@gcloud container clusters get-credentials $(CLUSTER_NAME) --zone $(ZONE) --project $(PROJECT_ID)

# Quick Setup
setup: gcp-login gcp-cluster-credentials secrets-setup secrets-sync ## Complete setup process
	@echo "✅ Complete setup finished!"
	@echo "ℹ️  Run 'make deploy-local' to deploy the application"


# Monitoring
monitor-secrets: ## Monitor secret access logs
	@echo "📊 Monitoring secret access logs..."
	@gcloud logging read "resource.type=secret_manager" --project=$(PROJECT_ID) --limit=10

monitor-pods: ## Monitor pod status
	@watch kubectl get pods

# Cleanup
clean-k8s: ## Clean up Kubernetes resources (useful before destroying infrastructure)
	@echo "🧹 Cleaning up Kubernetes resources..."
	@./scripts/cleanup-k8s-resources.sh

clean: clean-k8s ## Clean up all resources
	@echo "✅ Cleanup completed!"

# Documentation
docs: ## Open documentation
	@echo "📚 Documentation available in README.md"
	@echo "📖 View online at: https://github.com/Vitorspk/multi-k8s"