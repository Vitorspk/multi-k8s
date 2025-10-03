# 🚀 Multi-K8s - Full-Stack Application with Kubernetes on GKE

This project demonstrates a complete production application using Docker, Kubernetes, and Google Cloud Platform (GKE) with secure secret management via GCP Secret Manager.

## 📋 Table of Contents

- [Architecture](#-architecture)
- [Prerequisites](#-prerequisites)
- [Quick Setup](#-quick-setup)
- [Secret Manager](#-secret-manager)
- [Terraform Infrastructure](#-terraform-infrastructure)
- [Deployment](#-deployment)
- [Useful Commands](#-useful-commands)
- [Troubleshooting](#-troubleshooting)
- [Scripts Overview](#-scripts-overview)
- [Project Structure](#-project-structure)

## 🏗️ Architecture

### Application Components

- **Client**: React application (Nginx)
- **Server**: Node.js Express API
- **Worker**: Node.js background worker
- **PostgreSQL**: Database persistence
- **Redis**: In-memory caching

### Technologies Used

- **Container**: Docker
- **Orchestration**: Kubernetes (GKE)
- **Infrastructure**: Terraform
- **CI/CD**: GitHub Actions
- **Secret Management**: GCP Secret Manager
- **Cloud Provider**: Google Cloud Platform

## 📦 Prerequisites

### Required Tools

```bash
# Check installation
./scripts/validate.sh
```

- **gcloud CLI** - [Install Guide](https://cloud.google.com/sdk/docs/install)
- **kubectl** - [Install Guide](https://kubernetes.io/docs/tasks/tools/)
- **Docker** - [Install Guide](https://docs.docker.com/get-docker/)
- **Terraform** (optional) - [Install Guide](https://www.terraform.io/downloads)
- **Python 3** - For sync scripts

### GCP Account

- GCP project with billing enabled
- Required APIs will be enabled automatically

## 🚀 Quick Setup

### Via GitHub Actions (Recommended)

1. **Fork this repository**

2. **Configure GitHub Secrets:**
   - `GCP_PROJECT_ID`: Your GCP project ID
   - `GCP_SA_KEY`: Service Account JSON (will be created in setup)
   - `POSTGRES_PASSWORD`: PostgreSQL password

3. **Run Infrastructure Setup:**
   - Actions → Setup GKE Infrastructure → Run workflow → Apply

4. **Deploy Application:**
   - Push to `master` or `main` branch (automatic deploy)

### Via Local CLI

```bash
# 1. Clone the repository
git clone https://github.com/your-username/multi-k8s.git
cd multi-k8s

# 2. Configure environment variables
cp .env.example .env.local

# Edit .env.local with your settings:
# GCP_PROJECT_ID=your-gcp-project
# GCP_REGION=southamerica-east1
# POSTGRES_PASSWORD=your-secure-password

# 3. Complete setup
make setup

# 4. Deploy
make deploy-local
```

### 📝 Variable Configuration

The project uses a `.env.local` file for local configurations:

```bash
# Copy template
cp .env.example .env.local

# Main variables to configure:
GCP_PROJECT_ID=your-gcp-project          # GCP project ID
GCP_REGION=southamerica-east1           # Preferred region
POSTGRES_PASSWORD=your-secure-password  # PostgreSQL password
```

**Important:** The `.env.local` file is ignored by git for security.

## 🔐 Secret Manager

### Overview

The system uses GCP Secret Manager to securely manage all secrets:

- ✅ Centralized secrets in GCP
- ✅ Automatic synchronization with Kubernetes
- ✅ Versioning and auditing
- ✅ Easy rotation
- ✅ Zero hardcoded values

### Managed Secrets

#### Database Secrets (`database-secrets`)
- `PGPASSWORD` - PostgreSQL password
- `PGUSER` - PostgreSQL user
- `PGHOST` - PostgreSQL host
- `PGPORT` - PostgreSQL port
- `PGDATABASE` - Database name

#### Redis Secrets (`redis-secrets`)
- `REDIS_HOST` - Redis host
- `REDIS_PORT` - Redis port

### Secret Management

```bash
# Initial secret setup
./scripts/manage-secrets.sh setup

# List secrets
./scripts/manage-secrets.sh list

# Create/update a secret
./scripts/manage-secrets.sh create SECRET_NAME "value"

# Synchronize with Kubernetes
python3 scripts/sync-secrets.py

# Validate secrets
python3 scripts/sync-secrets.py --validate-only
```

### Secret Updates

1. **Update in Secret Manager:**
```bash
./scripts/manage-secrets.sh create postgres-password "new-secure-password"
```

2. **Synchronize with Kubernetes:**
```bash
python3 scripts/sync-secrets.py
```

3. **Restart pods if necessary:**
```bash
kubectl rollout restart deployment/server-deployment
```

## 🏗️ Terraform Infrastructure

### Created Resources

- **GKE Cluster** with Workload Identity
- **VPC Network** and Subnet
- **Node Pool** with autoscaling (1-3 nodes)
- **Service Account** for GKE
- **Global IP** for Ingress
- **Cloud Storage Bucket** for Terraform state

### Manual Terraform Setup

```bash
cd terraform

# Initialize
terraform init

# Plan changes
terraform plan

# Apply infrastructure
terraform apply

# Destroy (when necessary)
terraform destroy
```

### Configuration via GitHub Actions

1. Actions → Setup GKE Infrastructure
2. Select action: `plan`, `apply`, or `destroy`
3. Run workflow

## 📦 Deployment

### Deployment Order

1. **PostgreSQL** → Primary storage
2. **Redis** → Cache layer
3. **Server** → API backend
4. **Worker** → Background jobs
5. **Client** → Frontend
6. **Ingress** → Load balancer

### Automatic Deployment (CI/CD)

Push to `master` or `main` automatically triggers:

1. Docker image builds
2. Push to GCP Container Registry
3. Secret synchronization
4. Kubernetes deployment
5. Health verification

### Manual Deployment

```bash
# Complete deployment
make deploy-local

# Check status
kubectl get pods
kubectl get services

# Check logs
kubectl logs deployment/server-deployment
kubectl logs deployment/worker-deployment
```

## 🛠️ Useful Commands

### Makefile Commands

```bash
make help              # Show all commands
make setup             # Complete setup
make deploy-local      # Local deployment
make secrets-setup     # Setup secrets
make secrets-sync      # Synchronize secrets
make secrets-validate  # Validate secrets
make monitor-pods      # Monitor pods
make clean-k8s         # Clean Kubernetes resources
make clean             # Clean all resources
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
# Authentication
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

### Common Issues

#### Pods in Pending/CrashLoopBackOff

```bash
# Check events
kubectl describe pod POD_NAME

# Check logs
kubectl logs POD_NAME --previous

# Check resources
kubectl top nodes
```

#### PostgreSQL Authentication Error

```bash
# Check secret
kubectl describe secret database-secrets

# Re-synchronize secrets
python3 scripts/sync-secrets.py

# Restart pods
kubectl rollout restart deployment/server-deployment
```

#### Secret not found

```bash
# List secrets in GCP
gcloud secrets list --project=PROJECT_ID

# Create secret if necessary
./scripts/manage-secrets.sh create SECRET_NAME "value"
```

#### Permission denied

```bash
# Check IAM
gcloud projects get-iam-policy PROJECT_ID

# Add permission
gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="serviceAccount:SA_EMAIL" \
    --role="roles/secretmanager.secretAccessor"
```

#### When Terraform destroy hangs

If `terraform destroy` hangs on `ingress-nginx` namespace:

```bash
# Run manual cleanup
make clean-k8s

# Or run the script directly
./scripts/cleanup-k8s-resources.sh

# Then try destroy again
cd terraform && terraform destroy -auto-approve
```

### Logs and Monitoring

```bash
# Secret Manager logs
gcloud logging read "resource.type=secret_manager" --project=PROJECT_ID

# Pod logs
kubectl logs -l component=server --tail=100
kubectl logs -l component=worker --tail=100

# Real-time monitoring
kubectl logs -f deployment/server-deployment
```

## 📚 Scripts Overview

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `validate.sh` | Prerequisites validation | Before initial setup |
| `setup-gcp-permissions.sh` | Configure IAM and service account | Initial setup |
| `manage-secrets.sh` | Manage secrets in GCP | Secret management |
| `sync-secrets.py` | Synchronize secrets with K8s | During deployment |
| `cleanup-k8s-resources.sh` | Clean Kubernetes resources | Before destroy |

## 📁 Project Structure

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
│   ├── cleanup-k8s-resources.sh  # Limpar recursos K8s
│   ├── validate.sh       # Validação
│   └── lib/
│       └── common.sh     # Funções compartilhadas
└── Makefile              # Comandos facilitadores
```

## 🔒 Security

### Implemented Best Practices

- ✅ **Centralized secrets** in GCP Secret Manager
- ✅ **Service Accounts** with minimal permissions
- ✅ **Workload Identity** for pods
- ✅ **Network Policies** for isolation
- ✅ **HTTPS** via Ingress
- ✅ **Secret versioning**
- ✅ **Complete auditing** via GCP

### Required IAM Permissions

The Service Account used by GitHub Actions needs the following roles:

- `roles/storage.admin` - Manage buckets and objects in Cloud Storage
- `roles/artifactregistry.writer` - Push Docker images
- `roles/container.admin` - Manage GKE clusters
- `roles/compute.admin` - Manage compute resources
- `roles/iam.serviceAccountUser` - Use service accounts
- `roles/resourcemanager.projectIamAdmin` - Manage project IAM
- `roles/serviceusage.serviceUsageAdmin` - Enable GCP APIs
- `roles/secretmanager.admin` - Manage secrets in Secret Manager

To configure these permissions, run:
```bash
./scripts/setup-gcp-permissions.sh
```

### Security Checklist

- [ ] Never commit secrets in code
- [ ] Use Secret Manager secrets
- [ ] Rotate credentials regularly
- [ ] Review IAM permissions periodically
- [ ] Monitor access logs
- [ ] Keep Docker images updated

## 📊 Monitoring and Observability

### Available Metrics

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

### Configured Health Checks

- **Liveness Probes**: Checks if the container is alive
- **Readiness Probes**: Checks if it's ready to receive traffic
- **Startup Probes**: Extra time for initialization

## 🔄 CI/CD Pipeline

### GitHub Actions Flow

1. **Test** (on PRs)
   - Image builds
   - Test execution

2. **Deploy** (on push to main/master)
   - Build and push images
   - Secret synchronization
   - Kubernetes deployment
   - Health verification

3. **Infrastructure** (manual)
   - Terraform plan/apply/destroy
   - GKE cluster management

## 🤝 Contributing

1. Fork the project
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is open source and available under the MIT License.

## 🙏 Acknowledgments

- Google Cloud Platform for infrastructure
- Kubernetes community
- Docker community

## 📞 Support

For issues or questions:
- Open an [Issue](https://github.com/your-username/multi-k8s/issues)
- Check the [GKE documentation](https://cloud.google.com/kubernetes-engine/docs)
- Check the [logs](#logs-and-monitoring)

---

**Developed with ❤️ using Kubernetes and Google Cloud Platform**