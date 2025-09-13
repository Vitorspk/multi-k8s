#!/bin/bash

set -e

PROJECT_ID="vschiavo-home"
REGION="southamerica-east1"
ZONE="southamerica-east1-a"
CLUSTER_NAME="multi-k8s-cluster"

echo "=== Deploy Completo para GKE ==="
echo ""

echo "1. Configurando projeto GCP..."
gcloud config set project $PROJECT_ID

echo "2. Verificando se o cluster existe..."
if ! gcloud container clusters describe $CLUSTER_NAME --zone=$ZONE &>/dev/null; then
    echo "   Cluster não existe. Execute primeiro o Terraform:"
    echo "   cd terraform && terraform apply"
    exit 1
fi

echo "3. Obtendo credenciais do cluster..."
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE --project=$PROJECT_ID

echo "4. Criando secret para PostgreSQL (se não existir)..."
kubectl get secret pgpassword &>/dev/null || \
    kubectl create secret generic pgpassword --from-literal PGPASSWORD=postgres123

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