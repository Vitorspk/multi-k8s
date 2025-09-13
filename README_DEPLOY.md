# Deploy no GCP Kubernetes - Guia Completo

## 📋 Visão Geral

Este projeto implementa uma aplicação multi-container com:
- **Client**: React app
- **Server**: Node.js API  
- **Worker**: Background worker
- **Redis**: Cache/Queue
- **PostgreSQL**: Database

## 🚀 Setup Rápido

### ⚠️ Pré-requisitos de Segurança

**IMPORTANTE**: As credenciais não são mais hardcoded nos scripts. Configure as variáveis de ambiente primeiro:

```bash
# Opção 1: Use o script de configuração (recomendado)
chmod +x scripts/*.sh
./scripts/setup-env-vars.sh
source .env.local

# Opção 2: Configure manualmente
export GCP_PROJECT_ID='your-gcp-project-id'
export GCP_REGION='southamerica-east1'  # opcional
export POSTGRES_PASSWORD='your-secure-password'
export DOCKER_USERNAME='your-docker-username'
export DOCKER_PASSWORD='your-docker-password'
```

### Opção 1: Setup Automático Completo
```bash
# Primeiro configure as variáveis de ambiente
./scripts/setup-env-vars.sh
source .env.local

# Então execute o setup completo
./scripts/setup-complete.sh
```

### Opção 2: Setup Manual Passo a Passo

#### 1. Configurar Variáveis de Ambiente
```bash
./scripts/setup-env-vars.sh
source .env.local
```

#### 2. Configurar Service Account GCP
```bash
./scripts/setup-gcp-service-account.sh
```

#### 3. Criar Infraestrutura com Terraform
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edite terraform.tfvars com suas configurações
terraform init
terraform apply
cd ..
```

#### 4. Build e Push das Imagens Docker
```bash
./scripts/docker-build-push.sh
```

#### 5. Deploy no Kubernetes
```bash
./scripts/deploy-to-gke.sh
```

## 🔐 Melhorias de Segurança

### ✅ Correções Implementadas
- **Credenciais removidas**: Sem mais hardcoding de PROJECT_ID, senhas, etc.
- **Permissões reduzidas**: Service account usa `container.developer` em vez de `projectIamAdmin`
- **Senhas seguras**: Geração automática de senhas PostgreSQL
- **Validação de entrada**: Todos os scripts validam variáveis de ambiente
- **Melhor tratamento de erros**: Scripts param imediatamente em caso de falha

### 🛠️ Scripts Utilitários
```bash
# Configurar todas as variáveis de ambiente interativamente
./scripts/setup-env-vars.sh

# Gerar senha segura para PostgreSQL
./scripts/generate-postgres-password.sh
```

## 🔐 Configurar GitHub Actions

1. Acesse Settings > Secrets no seu repositório GitHub
2. Adicione os seguintes secrets:
   - `GCP_SA_KEY`: Conteúdo do arquivo `service-account.json`
   - `DOCKER_USERNAME`: Seu usuário do Docker Hub
   - `DOCKER_PASSWORD`: Sua senha/token do Docker Hub

## 📁 Estrutura do Projeto

```
multi-k8s/
├── .github/workflows/     # GitHub Actions CI/CD
│   ├── deploy.yml         # Deploy automático
│   └── test.yml          # Testes em PR
├── terraform/            # Infraestrutura como código
│   ├── main.tf          # Recursos GCP/GKE
│   ├── variables.tf     # Variáveis
│   ├── outputs.tf       # Outputs
│   └── kubernetes.tf    # Recursos K8s
├── k8s/                 # Manifestos Kubernetes
│   ├── client-config.yaml
│   ├── server-config.yaml
│   ├── worker-config.yaml
│   ├── postgres-config.yaml
│   ├── redis-config.yaml
│   └── ingress-service.yaml
├── scripts/             # Scripts de automação
│   ├── setup-gcp-service-account.sh
│   ├── docker-build-push.sh
│   ├── deploy-to-gke.sh
│   └── setup-complete.sh
└── [client, server, worker]/  # Código das aplicações
```

## 🛠️ Comandos Úteis

### Kubernetes
```bash
# Ver pods
kubectl get pods

# Ver logs
kubectl logs deployment/server-deployment

# Escalar deployment
kubectl scale deployment/client-deployment --replicas=3

# Acessar pod
kubectl exec -it [pod-name] -- bash

# Ver ingress IP
kubectl get ingress
```

### Terraform
```bash
# Ver recursos criados
terraform state list

# Destruir infraestrutura
terraform destroy

# Ver outputs
terraform output
```

## 💰 Otimização de Custos

A infraestrutura está configurada para mínimo custo:
- **Cluster**: 1 nó e2-small preemptível
- **Autoscaling**: 1-3 nós conforme demanda
- **Custo estimado**: ~$25-35/mês

## 🔄 CI/CD Pipeline

O GitHub Actions está configurado para:
1. **Em Push para master/main**: Deploy automático
2. **Em Pull Request**: Executa testes

## 📊 Monitoramento

```bash
# Status dos deployments
kubectl rollout status deployment/client-deployment

# Métricas do cluster
kubectl top nodes
kubectl top pods
```

## 🆘 Troubleshooting

### Problema: Pods não iniciam
```bash
kubectl describe pod [pod-name]
kubectl logs [pod-name]
```

### Problema: Ingress sem IP externo
```bash
kubectl get service -n ingress-nginx
kubectl describe ingress ingress-service
```

### Problema: Erro de permissão GCP
```bash
gcloud auth application-default login
gcloud config set project vschiavo-home
```

## 📝 Notas Importantes

1. **Segurança**: Nunca faça commit do arquivo `service-account.json`
2. **Secrets**: Use o Kubernetes Secrets para dados sensíveis
3. **Backup**: Configure backup regular do PostgreSQL
4. **Monitoring**: Configure alertas no GCP Monitoring

## 🔗 Links Úteis

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)