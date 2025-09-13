#!/bin/bash

set -e

PROJECT_ID="vschiavo-home"
REGION="southamerica-east1"
SERVICE_ACCOUNT_NAME="multi-k8s-deployer"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
KEY_FILE="service-account.json"

echo "=== Configurando Service Account GCP para Deploy ==="
echo "Projeto: $PROJECT_ID"
echo "Região: $REGION"
echo ""

echo "1. Configurando projeto..."
gcloud config set project $PROJECT_ID

echo "2. Criando Service Account..."
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
    --display-name="Multi-K8s Deployer" \
    --description="Service account for deploying multi-k8s application" \
    || echo "Service Account já existe"

echo "3. Atribuindo permissões necessárias..."

ROLES=(
    "roles/container.admin"
    "roles/storage.admin"
    "roles/compute.viewer"
    "roles/iam.serviceAccountUser"
    "roles/resourcemanager.projectIamAdmin"
)

for ROLE in "${ROLES[@]}"; do
    echo "   - Atribuindo role: $ROLE"
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
        --role="$ROLE" \
        --quiet
done

echo "4. Gerando chave JSON..."
gcloud iam service-accounts keys create $KEY_FILE \
    --iam-account=$SERVICE_ACCOUNT_EMAIL

echo "5. Validando configuração..."
gcloud auth activate-service-account --key-file=$KEY_FILE

echo ""
echo "✅ Service Account configurada com sucesso!"
echo "📁 Chave salva em: $KEY_FILE"
echo ""
echo "⚠️  IMPORTANTE:"
echo "   - Mantenha o arquivo $KEY_FILE seguro"
echo "   - Não faça commit deste arquivo no repositório"
echo "   - Adicione $KEY_FILE ao .gitignore"