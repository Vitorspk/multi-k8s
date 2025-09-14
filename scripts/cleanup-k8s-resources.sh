#!/bin/bash

# Script to clean up Kubernetes resources before destroying infrastructure
# This helps prevent stuck namespaces and resources during terraform destroy

set -e

echo "🧹 Starting Kubernetes resource cleanup..."

# Function to force delete a namespace
force_delete_namespace() {
    local namespace=$1
    echo "Attempting to delete namespace: $namespace"

    # First, try normal deletion
    kubectl delete namespace $namespace --ignore-not-found=true --timeout=30s 2>/dev/null || {
        echo "Normal deletion failed, trying force deletion..."

        # Remove finalizers
        kubectl get namespace $namespace -o json 2>/dev/null | \
            jq '.spec.finalizers = []' | \
            kubectl replace --raw "/api/v1/namespaces/$namespace/finalize" -f - 2>/dev/null || true

        # Force delete
        kubectl delete namespace $namespace --grace-period=0 --force --ignore-not-found=true 2>/dev/null || true
    }
}

# Clean up ingress-nginx namespace
if kubectl get namespace ingress-nginx &>/dev/null; then
    echo "📦 Cleaning up ingress-nginx namespace..."

    # Delete all resources in the namespace first
    kubectl delete all --all -n ingress-nginx --ignore-not-found=true --timeout=30s || true
    kubectl delete ingress --all -n ingress-nginx --ignore-not-found=true || true
    kubectl delete configmap --all -n ingress-nginx --ignore-not-found=true || true
    kubectl delete secret --all -n ingress-nginx --ignore-not-found=true || true
    kubectl delete serviceaccount --all -n ingress-nginx --ignore-not-found=true || true
    kubectl delete role --all -n ingress-nginx --ignore-not-found=true || true
    kubectl delete rolebinding --all -n ingress-nginx --ignore-not-found=true || true
    kubectl delete clusterrole --all -n ingress-nginx --ignore-not-found=true || true
    kubectl delete clusterrolebinding --all -n ingress-nginx --ignore-not-found=true || true

    # Delete validating webhook configurations
    kubectl delete validatingwebhookconfiguration ingress-nginx-admission --ignore-not-found=true || true

    # Now delete the namespace
    force_delete_namespace ingress-nginx
fi

# Clean up default namespace resources
echo "📦 Cleaning up default namespace resources..."
kubectl delete all --all -n default --ignore-not-found=true --timeout=30s || true
kubectl delete ingress --all -n default --ignore-not-found=true || true
kubectl delete pvc --all -n default --ignore-not-found=true || true
kubectl delete secret --all -n default --ignore-not-found=true || true

echo "✅ Kubernetes resource cleanup completed!"