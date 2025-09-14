# 🚀 Multi-K8s - Full-Stack Application with Kubernetes on GKE

Este projeto demonstra uma aplicação completa em produção usando Docker, Kubernetes, e Google Cloud Platform (GKE) com gerenciamento seguro de secrets via GCP Secret Manager.

## 📋 Índice

- [Arquitetura](#-arquitetura)
- [Pré-requisitos](#-pré-requisitos)
- [Setup Rápido](#-setup-rápido)
- [Secret Manager](#-secret-manager)
- [Terraform Infrastructure](#-terraform-infrastructure)
- [Deployment](#-deployment)
- [Comandos Úteis](#-comandos-úteis)
- [Troubleshooting](#-troubleshooting)
- [Scripts Overview](#-scripts-overview)
- [Estrutura do Projeto](#-estrutura-do-projeto)

## 🏗️ Arquitetura

### Componentes da Aplicação

- **Client**: React application (Nginx)
- **Server**: Node.js Express API
- **Worker**: Node.js background worker
- **PostgreSQL**: Database persistence
- **Redis**: In-memory caching

### Tecnologias Utilizadas

- **Container**: Docker
- **Orchestration**: Kubernetes (GKE)
- **Infrastructure**: Terraform
- **CI/CD**: GitHub Actions
- **Secret Management**: GCP Secret Manager
- **Cloud Provider**: Google Cloud Platform

## 📦 Pré-requisitos

### Ferramentas Necessárias

```bash
# Verificar instalação
./scripts/validate.sh
```

- **gcloud CLI** - [Install Guide](https://cloud.google.com/sdk/docs/install)
- **kubectl** - [Install Guide](https://kubernetes.io/docs/tasks/tools/)
- **Docker** - [Install Guide](https://docs.docker.com/get-docker/)
- **Terraform** (opcional) - [Install Guide](https://www.terraform.io/downloads)
- **Python 3** - Para scripts de sincronização

### Conta GCP

- Projeto GCP com billing habilitado
- APIs necessárias serão habilitadas automaticamente

## 🚀 Setup Rápido

### Via GitHub Actions (Recomendado)

1. **Fork este repositório**

2. **Configure os Secrets no GitHub:**
   - `GCP_PROJECT_ID`: Seu ID do projeto GCP
   - `GCP_SA_KEY`: Service Account JSON (será criado no setup)
   - `POSTGRES_PASSWORD`: Senha para o PostgreSQL

3. **Execute o Setup de Infraestrutura:**
   - Actions → Setup GKE Infrastructure → Run workflow → Apply

4. **Deploy da Aplicação:**
   - Push para branch `master` ou `main` (deploy automático)

### Via CLI Local

```bash
# 1. Clone o repositório
git clone https://github.com/seu-usuario/multi-k8s.git
cd multi-k8s

# 2. Configure o projeto GCP
export GCP_PROJECT_ID='seu-projeto-gcp'
export GCP_REGION='southamerica-east1'

# 3. Setup completo
make setup

# 4. Deploy
make deploy-local
```

## 🔐 Secret Manager

### Visão Geral

O sistema usa GCP Secret Manager para gerenciar todos os secrets de forma segura:

- ✅ Secrets centralizados no GCP
- ✅ Sincronização automática com Kubernetes
- ✅ Versionamento e auditoria
- ✅ Rotação facilitada
- ✅ Zero valores hardcoded

### Secrets Gerenciados

#### Database Secrets (`database-secrets`)
- `PGPASSWORD` - Senha do PostgreSQL
- `PGUSER` - Usuário do PostgreSQL
- `PGHOST` - Host do PostgreSQL
- `PGPORT` - Porta do PostgreSQL
- `PGDATABASE` - Nome do banco de dados

#### Redis Secrets (`redis-secrets`)
- `REDIS_HOST` - Host do Redis
- `REDIS_PORT` - Porta do Redis

### Gerenciamento de Secrets

```bash
# Setup inicial dos secrets
./scripts/manage-secrets.sh setup

# Listar secrets
./scripts/manage-secrets.sh list

# Criar/atualizar um secret
./scripts/manage-secrets.sh create SECRET_NAME "valor"

# Sincronizar com Kubernetes
python3 scripts/sync-secrets.py

# Validar secrets
python3 scripts/sync-secrets.py --validate-only
```

### Atualização de Secrets

1. **Atualizar no Secret Manager:**
```bash
./scripts/manage-secrets.sh create postgres-password "nova-senha-segura"
```

2. **Sincronizar com Kubernetes:**
```bash
python3 scripts/sync-secrets.py
```

3. **Reiniciar pods se necessário:**
```bash
kubectl rollout restart deployment/server-deployment
```

## 🏗️ Terraform Infrastructure

### Recursos Criados

- **GKE Cluster** com Workload Identity
- **VPC Network** e Subnet
- **Node Pool** com autoscaling (1-3 nodes)
- **Service Account** para GKE
- **Global IP** para Ingress
- **Cloud Storage Bucket** para Terraform state

### Setup Manual do Terraform

```bash
cd terraform

# Inicializar
terraform init

# Planejar mudanças
terraform plan

# Aplicar infraestrutura
terraform apply

# Destruir (quando necessário)
terraform destroy
```

### Configuração via GitHub Actions

1. Actions → Setup GKE Infrastructure
2. Selecionar ação: `plan`, `apply`, ou `destroy`
3. Executar workflow

## 📦 Deployment

### Ordem de Deploy

1. **PostgreSQL** → Storage principal
2. **Redis** → Cache layer
3. **Server** → API backend
4. **Worker** → Background jobs
5. **Client** → Frontend
6. **Ingress** → Load balancer

### Deploy Automático (CI/CD)

Push para `master` ou `main` dispara automaticamente:

1. Build das imagens Docker
2. Push para GCP Container Registry
3. Sincronização de secrets
4. Deploy no Kubernetes
5. Verificação de saúde

### Deploy Manual

```bash
# Deploy completo
make deploy-local

# Verificar status
kubectl get pods
kubectl get services

# Verificar logs
kubectl logs deployment/server-deployment
kubectl logs deployment/worker-deployment
```

## 🛠️ Comandos Úteis

### Makefile Commands

```bash
make help              # Mostrar todos os comandos
make setup             # Setup completo
make deploy-local      # Deploy local
make secrets-setup     # Configurar secrets
make secrets-sync      # Sincronizar secrets
make secrets-validate  # Validar secrets
make monitor-pods      # Monitorar pods
make clean             # Limpar recursos
```

### Kubernetes Commands

```bash
# Pods
kubectl get pods
kubectl describe pod POD_NAME
kubectl logs POD_NAME
kubectl exec -it POD_NAME -- bash

# Services
kubectl get services
kubectl get ingress

# Secrets
kubectl get secrets
kubectl describe secret database-secrets

# Debugging
kubectl get events
kubectl top nodes
kubectl top pods
```

### GCloud Commands

```bash
# Autenticação
gcloud auth login
gcloud config set project PROJECT_ID

# Cluster
gcloud container clusters list
gcloud container clusters get-credentials CLUSTER_NAME --zone ZONE

# Secrets
gcloud secrets list
gcloud secrets versions list SECRET_NAME
```

## 🆘 Troubleshooting

### Problemas Comuns

#### Pods em Pending/CrashLoopBackOff

```bash
# Verificar eventos
kubectl describe pod POD_NAME

# Verificar logs
kubectl logs POD_NAME --previous

# Verificar recursos
kubectl top nodes
```

#### Erro de Autenticação com PostgreSQL

```bash
# Verificar secret
kubectl describe secret database-secrets

# Re-sincronizar secrets
python3 scripts/sync-secrets.py

# Reiniciar pods
kubectl rollout restart deployment/server-deployment
```

#### Secret não encontrado

```bash
# Listar secrets no GCP
gcloud secrets list --project=PROJECT_ID

# Criar secret se necessário
./scripts/manage-secrets.sh create SECRET_NAME "valor"
```

#### Permissão negada

```bash
# Verificar IAM
gcloud projects get-iam-policy PROJECT_ID

# Adicionar permissão
gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="serviceAccount:SA_EMAIL" \
    --role="roles/secretmanager.secretAccessor"
```

### Logs e Monitoramento

```bash
# Logs do Secret Manager
gcloud logging read "resource.type=secret_manager" --project=PROJECT_ID

# Logs dos pods
kubectl logs -l component=server --tail=100
kubectl logs -l component=worker --tail=100

# Monitorar em tempo real
kubectl logs -f deployment/server-deployment
```

## 📚 Scripts Overview

| Script | Propósito | Quando Usar |
|--------|-----------|-------------|
| `validate.sh` | Validação de pré-requisitos | Antes do setup inicial |
| `setup-gcp-permissions.sh` | Configurar IAM e service account | Setup inicial |
| `manage-secrets.sh` | Gerenciar secrets no GCP | Gestão de secrets |
| `sync-secrets.py` | Sincronizar secrets com K8s | Durante deploy |
| `wait-for-dependencies.sh` | Verificar serviços prontos | Após deploy |

## 📁 Estrutura do Projeto

```
multi-k8s/
├── .github/
│   └── workflows/         # GitHub Actions CI/CD
│       ├── deploy.yml     # Deploy automático
│       ├── setup-infrastructure.yml  # Setup Terraform
│       └── test.yml       # Testes
├── client/                # React Frontend
│   ├── src/
│   ├── public/
│   ├── Dockerfile         # Produção
│   └── Dockerfile.dev     # Desenvolvimento
├── server/                # Node.js API
│   ├── index.js
│   ├── Dockerfile
│   └── Dockerfile.dev
├── worker/                # Background Worker
│   ├── index.js
│   ├── Dockerfile
│   └── Dockerfile.dev
├── k8s/                   # Kubernetes Configs
│   ├── client-config.yaml
│   ├── server-config.yaml
│   ├── worker-config.yaml
│   ├── postgres-config.yaml
│   ├── redis-config.yaml
│   └── ingress-service.yaml
├── terraform/             # Infrastructure as Code
│   ├── main.tf           # GCP/GKE resources
│   ├── kubernetes.tf     # K8s resources
│   ├── variables.tf      # Input variables
│   └── outputs.tf        # Output values
├── scripts/               # Automation Scripts
│   ├── manage-secrets.sh # Gerenciar secrets
│   ├── sync-secrets.py   # Sincronizar secrets
│   ├── setup-gcp-permissions.sh  # Setup IAM
│   ├── wait-for-dependencies.sh  # Verificar serviços
│   ├── validate.sh       # Validação
│   └── lib/
│       └── common.sh     # Funções compartilhadas
└── Makefile              # Comandos facilitadores
```

## 🔒 Segurança

### Boas Práticas Implementadas

- ✅ **Secrets centralizados** no GCP Secret Manager
- ✅ **Service Accounts** com permissões mínimas
- ✅ **Workload Identity** para pods
- ✅ **Network Policies** para isolamento
- ✅ **HTTPS** via Ingress
- ✅ **Versionamento** de secrets
- ✅ **Auditoria** completa via GCP

### Permissões IAM Necessárias

O Service Account usado pelo GitHub Actions precisa das seguintes roles:

- `roles/storage.admin` - Gerenciar buckets e objetos no Cloud Storage
- `roles/artifactregistry.writer` - Push de imagens Docker
- `roles/container.admin` - Gerenciar clusters GKE
- `roles/compute.admin` - Gerenciar recursos de computação
- `roles/iam.serviceAccountUser` - Usar service accounts
- `roles/resourcemanager.projectIamAdmin` - Gerenciar IAM do projeto
- `roles/serviceusage.serviceUsageAdmin` - Habilitar APIs do GCP
- `roles/secretmanager.admin` - Gerenciar secrets no Secret Manager

Para configurar essas permissões, execute:
```bash
./scripts/setup-gcp-permissions.sh
```

### Checklist de Segurança

- [ ] Nunca commitar secrets no código
- [ ] Usar secrets do Secret Manager
- [ ] Rotacionar credenciais regularmente
- [ ] Revisar permissões IAM periodicamente
- [ ] Monitorar logs de acesso
- [ ] Manter imagens Docker atualizadas

## 📊 Monitoramento e Observabilidade

### Métricas Disponíveis

```bash
# Resource usage
kubectl top nodes
kubectl top pods

# Application health
kubectl get pods --watch
kubectl get events --watch

# GCP Monitoring
gcloud monitoring dashboards list
```

### Health Checks Configurados

- **Liveness Probes**: Verifica se o container está vivo
- **Readiness Probes**: Verifica se está pronto para receber tráfego
- **Startup Probes**: Tempo extra para inicialização

## 🔄 CI/CD Pipeline

### Fluxo do GitHub Actions

1. **Test** (em PRs)
   - Build das imagens
   - Execução de testes

2. **Deploy** (em push para main/master)
   - Build e push das imagens
   - Sincronização de secrets
   - Deploy no Kubernetes
   - Verificação de saúde

3. **Infrastructure** (manual)
   - Terraform plan/apply/destroy
   - Gestão do cluster GKE

## 🤝 Contribuindo

1. Fork o projeto
2. Crie uma feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📝 Licença

Este projeto é open source e está disponível sob a licença MIT.

## 🙏 Agradecimentos

- Google Cloud Platform pela infraestrutura
- Kubernetes community
- Docker community

## 📞 Suporte

Para problemas ou dúvidas:
- Abra uma [Issue](https://github.com/seu-usuario/multi-k8s/issues)
- Consulte a [documentação do GKE](https://cloud.google.com/kubernetes-engine/docs)
- Verifique os [logs](#logs-e-monitoramento)

---

**Desenvolvido com ❤️ usando Kubernetes e Google Cloud Platform**