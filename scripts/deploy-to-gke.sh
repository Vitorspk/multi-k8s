#!/bin/bash

set -e

# Validate required environment variables
if [[ -z "${GCP_PROJECT_ID}" ]]; then
    echo "❌ Error: GCP_PROJECT_ID environment variable is required"
    echo "Usage: export GCP_PROJECT_ID='your-project-id'"
    exit 1
fi

if [[ -z "${GCP_REGION}" ]]; then
    echo "⚠️  Warning: GCP_REGION not set, using default: southamerica-east1"
    GCP_REGION="southamerica-east1"
fi

if [[ -z "${POSTGRES_PASSWORD}" ]]; then
    echo "❌ Error: POSTGRES_PASSWORD environment variable is required"
    echo "Usage: export POSTGRES_PASSWORD='your-secure-password'"
    exit 1
fi

PROJECT_ID="${GCP_PROJECT_ID}"
REGION="${GCP_REGION}"
ZONE="${GCP_REGION}-a"
CLUSTER_NAME="multi-k8s-cluster"

echo "=== Deploy Completo para GKE ==="
echo ""

echo "1. Configurando projeto GCP..."
if ! gcloud config set project $PROJECT_ID; then
    echo "❌ Error: Failed to set GCP project. Check if project exists and you have access."
    exit 1
fi

echo "2. Verificando se o cluster existe..."
if ! gcloud container clusters describe $CLUSTER_NAME --zone=$ZONE &>/dev/null; then
    echo "❌ Error: Cluster '$CLUSTER_NAME' não existe na zona '$ZONE'"
    echo "   Execute primeiro o Terraform:"
    echo "   cd terraform && terraform apply"
    exit 1
fi

echo "3. Obtendo credenciais do cluster..."
if ! gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE --project=$PROJECT_ID; then
    echo "❌ Error: Failed to get cluster credentials. Check your access permissions."
    exit 1
fi

echo "4. Criando secret para PostgreSQL (se não existir)..."
if ! kubectl get secret pgpassword &>/dev/null; then
    if ! kubectl create secret generic pgpassword --from-literal PGPASSWORD="${POSTGRES_PASSWORD}"; then
        echo "❌ Error: Failed to create PostgreSQL secret"
        exit 1
    fi
    echo "   ✅ PostgreSQL secret created"
else
    echo "   ✅ PostgreSQL secret already exists"
fi

echo "5. Verificando NGINX Ingress Controller..."
kubectl get namespace ingress-nginx &>/dev/null || \
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

echo "6. Aguardando NGINX Ingress Controller..."
kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s

echo "7. Aplicando configurações Kubernetes..."
kubectl apply -f k8s/

echo "8. Verificando deployments..."
kubectl rollout status deployment/client-deployment
kubectl rollout status deployment/server-deployment
kubectl rollout status deployment/worker-deployment
kubectl rollout status deployment/postgres-deployment

echo "9. Obtendo IP do Load Balancer..."
echo -n "   Aguardando IP externo"
while [ -z "$EXTERNAL_IP" ]; do
    echo -n "."
    EXTERNAL_IP=$(kubectl get service ingress-nginx-controller \
        -n ingress-nginx \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    sleep 2
done
echo ""

echo ""
echo "✅ Deploy concluído com sucesso!"
echo ""
echo "📊 Status dos recursos:"
kubectl get deployments
echo ""
kubectl get services
echo ""
kubectl get ingress
echo ""
echo "🌐 Acesse a aplicação em: http://$EXTERNAL_IP"
echo ""
echo "💡 Dicas:"
echo "   - Ver logs: kubectl logs deployment/[nome-deployment]"
echo "   - Ver pods: kubectl get pods"
echo "   - Escalar: kubectl scale deployment/[nome] --replicas=3"