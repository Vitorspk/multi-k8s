# Multi-K8s - Aplicação Multi-Container no Google Kubernetes Engine

## 📋 Visão Geral

Aplicação multi-container completa implementando calculadora Fibonacci com arquitetura de microserviços:

- **Client**: React App (Frontend)
- **Server**: Node.js API (Backend)  
- **Worker**: Background Worker (Processamento)
- **PostgreSQL**: Database (Persistência)
- **Redis**: Cache & Message Queue
- **NGINX**: Ingress Controller

### Arquitetura

```
Internet → Load Balancer → Ingress Controller
                                ├── /* → Client (React)
                                └── /api/* → Server (Node.js)
                                              ├── PostgreSQL
                                              └── Redis ← Worker
```

## 🚀 Setup Rápido

### Pré-requisitos

- GCP Project configurado
- `gcloud` CLI instalado e autenticado
- `kubectl` CLI instalado
- `terraform` CLI instalado (v1.0+)
- `docker` instalado
- Docker Hub account
- GitHub repository (para CI/CD)

## 📋 Deployment Flow

### Initial Setup (Run Once)

#### 1. Configure GCP Service Account
```bash
# Set environment variables
export GCP_PROJECT_ID="your-project-id"
export GCP_REGION="southamerica-east1"

# Run setup script (creates service account and optionally Terraform backend)
./scripts/setup-gcp-permissions.sh

# Copy the service account key to GitHub Secrets
cat service-account.json | pbcopy
# Add to GitHub: Settings > Secrets > Actions > GCP_SA_KEY
```

#### 2. Create Infrastructure

**Option A: Via GitHub Actions (Recommended)**
1. Configure GitHub Secrets (see section below)
2. Go to **Actions** → **Setup GKE Infrastructure**
3. Click **Run workflow** → Select **apply** → **Run**
4. Wait for cluster creation (~10-15 minutes)

**Option B: Via Terraform Local**
```bash
cd terraform
terraform init
terraform apply -auto-approve
cd ..
```

### Manual Setup (Alternative)

#### 1️⃣ Configure Environment Variables

```bash
# Interactive setup (recommended)
./scripts/setup-env-vars.sh
source .env.local

# Or manually export
export GCP_PROJECT_ID='your-gcp-project-id'
export GCP_REGION='southamerica-east1'
export POSTGRES_PASSWORD='your-secure-password'
export DOCKER_USERNAME='your-docker-username'
export DOCKER_PASSWORD='your-docker-password'
```

#### 2️⃣ Setup GCP Permissions

```bash
# Creates service account with proper permissions
# Optionally creates Terraform backend bucket
./scripts/setup-gcp-permissions.sh
```

#### 3️⃣ Create Infrastructure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings

terraform init
terraform plan
terraform apply
cd ..
```

#### 4️⃣ Deploy Application

```bash
# Build and push Docker images (optional, CI/CD does this)
./scripts/docker-build-push.sh

# Deploy to GKE
./scripts/deploy-to-gke.sh

# Verify deployment
./scripts/wait-for-dependencies.sh
```

## 🔄 Ordem de Deploy (Importante!)

A ordem correta de deployment garante que todas as dependências sejam satisfeitas:

### Fase 1: Infraestrutura (Terraform)
```
VPC Network → Subnet → GKE Cluster → Node Pool → Service Account
```

### Fase 2: Prerequisites Kubernetes
```bash
# Namespace e NGINX Ingress
kubectl apply -f k8s/00-prerequisites.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Secret do PostgreSQL
kubectl create secret generic pgpassword \
  --from-literal=PGPASSWORD=$POSTGRES_PASSWORD \
  -n multi-k8s
```

### Fase 3: Storage Services (Paralelo)
```bash
kubectl apply -f k8s/postgres-config.yaml -n multi-k8s
kubectl apply -f k8s/redis-config.yaml -n multi-k8s
```

### Fase 4: Application Services
```bash
# Server depende de PostgreSQL + Redis
kubectl apply -f k8s/server-config.yaml -n multi-k8s

# Worker depende apenas de Redis
kubectl apply -f k8s/worker-config.yaml -n multi-k8s
```

### Fase 5: Frontend e Routing
```bash
kubectl apply -f k8s/client-config.yaml -n multi-k8s
kubectl apply -f k8s/ingress-service.yaml -n multi-k8s
```

### Verificação
```bash
./scripts/wait-for-dependencies.sh
```

## 🔐 Configuração GitHub Actions CI/CD

### Secrets Obrigatórios

Configure em: **Settings → Secrets and variables → Actions**

| Secret | Descrição | Como Obter |
|--------|-----------|------------|
| `GCP_PROJECT_ID` | ID do projeto GCP | Console GCP |
| `GCP_SA_KEY` | Service Account JSON | `cat service-account.json` |
| `DOCKER_USERNAME` | Usuário Docker Hub | Docker Hub account |
| `DOCKER_PASSWORD` | Token Docker Hub | Docker Hub → Settings → Security → Access Tokens |
| `POSTGRES_PASSWORD` | Senha PostgreSQL | `openssl rand -base64 32` |

### Secrets Opcionais (com defaults)

- `GKE_CLUSTER_NAME`: Default `multi-k8s-cluster`
- `GKE_ZONE`: Default `southamerica-east1-a`
- `DEPLOYMENT_NAME`: Default `multi-k8s`

### Pipeline

- **Push para master/main**: Deploy automático
- **Pull Request**: Executa testes

## 📁 Estrutura do Projeto

```
multi-k8s/
├── .github/workflows/        # CI/CD
│   ├── deploy.yml           # Deploy automático
│   └── test.yml            # Testes em PR
├── client/                  # React Frontend
│   ├── src/                # Código fonte
│   ├── nginx/              # Configuração NGINX
│   ├── Dockerfile          # Produção
│   └── Dockerfile.dev      # Desenvolvimento
├── server/                  # Node.js API
│   ├── index.js           # API endpoints
│   ├── keys.js            # Configurações
│   └── Dockerfile
├── worker/                  # Background Worker
│   ├── index.js           # Fibonacci otimizado
│   └── Dockerfile
├── k8s/                    # Kubernetes Manifests
│   ├── 00-prerequisites.yaml    # Namespace & NetworkPolicy
│   ├── client-config.yaml      # Frontend deployment
│   ├── server-config.yaml      # API deployment
│   ├── worker-config.yaml      # Worker deployment
│   ├── postgres-config.yaml    # Database + PVC
│   ├── redis-config.yaml       # Cache deployment
│   └── ingress-service.yaml    # Routing rules
├── terraform/              # Infrastructure as Code
│   ├── main.tf            # GCP/GKE resources
│   ├── kubernetes.tf      # K8s resources
│   ├── variables.tf      # Input variables
│   └── outputs.tf        # Output values
└── scripts/               # Automation Scripts
    ├── setup-env-vars.sh          # Configure environment variables
    ├── setup-gcp-permissions.sh   # Setup GCP service account & bucket
    ├── docker-build-push.sh       # Build and push Docker images
    ├── deploy-to-gke.sh           # Deploy to Kubernetes
    ├── wait-for-dependencies.sh   # Verify services are ready
    └── validate-k8s-configs.sh    # Validate K8s configurations
```

## 🛠️ Comandos Úteis

### Kubernetes

```bash
# Status dos recursos
kubectl get all -n multi-k8s

# Logs
kubectl logs deployment/server-deployment -n multi-k8s
kubectl logs deployment/worker-deployment -n multi-k8s

# Escalar
kubectl scale deployment/client-deployment --replicas=5 -n multi-k8s

# Acessar pod
kubectl exec -it deployment/postgres-deployment -n multi-k8s -- psql -U postgres

# IP externo
kubectl get ingress -n multi-k8s

# Métricas
kubectl top nodes
kubectl top pods -n multi-k8s
```

### Terraform

```bash
# Ver recursos
terraform state list

# Outputs
terraform output

# Destruir tudo
terraform destroy
```

### Docker

```bash
# Build local
docker build -t multi-client ./client
docker build -t multi-server ./server
docker build -t multi-worker ./worker

# Run local
docker-compose up
```

## 💰 Otimização de Custos

Configuração para mínimo custo:

- **Cluster**: 1 nó e2-small preemptível
- **Autoscaling**: 1-3 nós conforme demanda
- **Região**: southamerica-east1 (São Paulo)
- **Custo estimado**: ~$25-35/mês

### Reduzir custos ainda mais:

```bash
# Usar apenas 1 réplica de cada serviço
kubectl scale deployment/client-deployment --replicas=1 -n multi-k8s
kubectl scale deployment/server-deployment --replicas=1 -n multi-k8s

# Pausar cluster quando não usar
gcloud container clusters resize multi-k8s-cluster --num-nodes=0 --zone=southamerica-east1-a
```

## 🔒 Segurança Implementada

### ✅ Melhorias Aplicadas

- **Sem hardcoding**: Todas as credenciais via environment variables
- **Secrets K8s**: PostgreSQL password como secret
- **Service Account**: Permissões mínimas necessárias
- **Network Policy**: Isolamento de rede entre pods
- **Resource Limits**: Limites de CPU/memória definidos
- **Health Checks**: Liveness/Readiness probes configurados
- **Versões específicas**: Imagens com tags específicas (não latest)
- **Graceful Shutdown**: Handlers SIGTERM/SIGINT

### Recomendações Adicionais

1. Use Google Secret Manager para secrets
2. Implemente RBAC detalhado
3. Configure backup automático do PostgreSQL
4. Use Workload Identity para pods
5. Escaneie imagens com Trivy/Snyk
6. Implemente Pod Security Policies

## 📊 Monitoramento

### Comandos de Monitoramento

```bash
# Status geral
kubectl get deployments -n multi-k8s
kubectl get pods -n multi-k8s
kubectl get services -n multi-k8s

# Verificar rollout
kubectl rollout status deployment/client-deployment -n multi-k8s
kubectl rollout status deployment/server-deployment -n multi-k8s

# Histórico de rollout
kubectl rollout history deployment/server-deployment -n multi-k8s

# Logs em tempo real
kubectl logs -f deployment/server-deployment -n multi-k8s
```

### Endpoints de Health Check

- Client: `http://<EXTERNAL_IP>/`
- API Server: `http://<EXTERNAL_IP>/api/`
- API Values: `http://<EXTERNAL_IP>/api/values/current`

## 📚 Scripts Overview

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `validate-project.sh` | **Complete project validation** - checks all dependencies and configs | Run first to verify setup |
| `setup-gcp-permissions.sh` | Creates service account with proper permissions & optionally Terraform backend | Initial setup only |
| `setup-env-vars.sh` | Interactive environment variable configuration | Local development setup |
| `deploy-to-gke.sh` | Manual deployment to GKE cluster | Local testing/debugging |
| `docker-build-push.sh` | Build and push Docker images | Local testing (CI/CD handles this automatically) |
| `validate-k8s-configs.sh` | Validate Kubernetes configurations | Before deployment |
| `wait-for-dependencies.sh` | Wait for all services to be ready | After deployment |

## 🆘 Troubleshooting

### Permission Denied Error (storage.buckets.create)

```
AccessDeniedException: 403 multi-k8s-deployer@***.iam.gserviceaccount.com does not have storage.buckets.create access
```

**Solution**:
1. Run `./scripts/setup-gcp-permissions.sh` locally
2. Update GitHub Secret with new service account key: `cat service-account.json | pbcopy`
3. Re-run the workflow

### Cluster Not Found (404 Not Found)

```
ERROR: (gcloud.container.clusters.get-credentials) ResponseError: code=404, message=Not found
```

**Solution**: The GKE cluster hasn't been created yet. Create it first:

1. **Via GitHub Actions**: Actions → Setup GKE Infrastructure → Run workflow → apply
2. **Via Terminal**: `cd terraform && terraform apply`

### Pods não iniciam

```bash
kubectl describe pod <pod-name> -n multi-k8s
kubectl logs <pod-name> -n multi-k8s --previous
```

### Ingress sem IP externo

```bash
kubectl get service -n ingress-nginx
kubectl describe ingress ingress-service -n multi-k8s
```

### Erro de conexão PostgreSQL/Redis

```bash
# Verificar services
kubectl get endpoints -n multi-k8s

# Testar conexão
kubectl run -it --rm debug --image=busybox --restart=Never -n multi-k8s -- sh
> nslookup postgres-cluster-ip-service
> nslookup redis-cluster-ip-service
```

### Erro de permissão GCP

```bash
gcloud auth application-default login
gcloud config set project $GCP_PROJECT_ID
```

## 🔄 Updates e Rollbacks

### Update de imagem

```bash
kubectl set image deployment/server-deployment \
  server=$DOCKER_USERNAME/multi-server:v2 \
  -n multi-k8s
```

### Rollback

```bash
kubectl rollout undo deployment/server-deployment -n multi-k8s
```

## 📝 API Endpoints

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/` | Health check |
| GET | `/api/values/all` | Todos os valores (PostgreSQL) |
| GET | `/api/values/current` | Valores em cache (Redis) |
| POST | `/api/values` | Calcular novo Fibonacci |

### Exemplo de uso:

```bash
# Submeter novo cálculo
curl -X POST http://<EXTERNAL_IP>/api/values \
  -H "Content-Type: application/json" \
  -d '{"index": 10}'

# Ver resultados
curl http://<EXTERNAL_IP>/api/values/current
```

## 🚀 Desenvolvimento Local

```bash
# Criar arquivo docker-compose.yml para desenvolvimento local
docker-compose -f docker-compose.dev.yml up

# Acessar:
# - Frontend: http://localhost:3000
# - API: http://localhost:5000
```

## 📚 Tecnologias Utilizadas

- **Frontend**: React 18, React Router, Axios
- **Backend**: Node.js, Express, PostgreSQL client, Redis client
- **Database**: PostgreSQL 15 Alpine
- **Cache**: Redis 7 Alpine
- **Container**: Docker, Multi-stage builds
- **Orchestration**: Kubernetes 1.27+
- **Infrastructure**: Terraform, Google Cloud Platform
- **CI/CD**: GitHub Actions
- **Routing**: NGINX Ingress Controller

## 🔗 Links Úteis

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [NGINX Ingress](https://kubernetes.github.io/ingress-nginx/)
- [Docker Hub](https://hub.docker.com/)

## 📄 Licença

MIT License - Veja LICENSE para detalhes

## 👥 Contribuindo

1. Fork o projeto
2. Crie sua feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## ✨ Autor

**Vitor Schiavo**
- GitHub: [@Vitorspk](https://github.com/Vitorspk)

---

**Última atualização:** Setembro 2024 | **Versão:** 2.0.0