#!/bin/bash

set -e

echo "=== Setup Completo do Projeto Multi-K8s no GCP ==="
echo ""
echo "Projeto: vschiavo-home"
echo "Região: southamerica-east1"
echo ""

echo "📋 Passo 1: Configurar Service Account GCP"
echo "----------------------------------------"
./scripts/setup-gcp-service-account.sh

echo ""
echo "📋 Passo 2: Criar Infraestrutura com Terraform"
echo "-----------------------------------------------"
cd terraform

if [ ! -f terraform.tfvars ]; then
    echo "Criando arquivo terraform.tfvars..."
    cp terraform.tfvars.example terraform.tfvars
    echo ""
    echo "⚠️  IMPORTANTE: Edite o arquivo terraform/terraform.tfvars com:"
    echo "   - docker_username: Seu usuário do Docker Hub"
    echo "   - postgres_password: Uma senha segura"
    echo ""
    read -p "Pressione ENTER após editar o arquivo..."
fi

echo "Inicializando Terraform..."
terraform init

echo "Aplicando infraestrutura..."
terraform apply

cd ..

echo ""
echo "📋 Passo 3: Build e Push das Imagens Docker"
echo "--------------------------------------------"
./scripts/docker-build-push.sh

echo ""
echo "📋 Passo 4: Deploy da Aplicação no Kubernetes"
echo "----------------------------------------------"
./scripts/deploy-to-gke.sh

echo ""
echo "🎉 Setup completo!"
echo ""
echo "📌 Próximos passos:"
echo "   1. Configure os secrets no GitHub:"
echo "      - GCP_SA_KEY: Conteúdo do arquivo service-account.json"
echo "      - DOCKER_USERNAME: Seu usuário do Docker Hub"
echo "      - DOCKER_PASSWORD: Sua senha do Docker Hub"
echo ""
echo "   2. Faça commit e push para ativar o CI/CD:"
echo "      git add ."
echo "      git commit -m 'Setup GKE deployment'"
echo "      git push origin master"