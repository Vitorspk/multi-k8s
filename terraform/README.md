# Terraform Infrastructure for Multi-K8s

## Pré-requisitos

1. Terraform instalado (>= 1.0)
2. gcloud CLI configurado
3. kubectl instalado
4. Conta GCP com projeto configurado

## Configuração Inicial

1. **Copie o arquivo de variáveis:**
```bash
cp terraform.tfvars.example terraform.tfvars
```

2. **Edite o arquivo terraform.tfvars com suas configurações:**
- `docker_username`: Seu usuário do Docker Hub
- `postgres_password`: Senha segura para o PostgreSQL

3. **Inicialize o Terraform:**
```bash
terraform init
```

## Deploy da Infraestrutura

1. **Visualize as mudanças:**
```bash
terraform plan
```

2. **Aplique a infraestrutura:**
```bash
terraform apply
```

3. **Configure kubectl (executado automaticamente pelo Terraform):**
```bash
gcloud container clusters get-credentials multi-k8s-cluster --zone southamerica-east1-a --project vschiavo-home
```

## Recursos Criados

- **GKE Cluster**: Cluster Kubernetes com configuração mínima
- **VPC e Subnet**: Rede isolada para o cluster
- **Node Pool**: Pool de nós com autoscaling (1-3 nós)
- **Service Account**: Conta de serviço para o cluster
- **Static IP**: IP estático para o Ingress
- **Storage Bucket**: Bucket para estado do Terraform
- **Kubernetes Resources**:
  - Secret para PostgreSQL
  - NGINX Ingress Controller

## Configuração do Cluster

- **Região**: southamerica-east1
- **Zona**: southamerica-east1-a
- **Tipo de máquina**: e2-small (economia)
- **Nós preemptíveis**: Habilitado (economia de até 80%)
- **Autoscaling**: 1-3 nós

## Custos Estimados

Com a configuração mínima:
- **1 nó e2-small preemptível**: ~$5-10/mês
- **Load Balancer**: ~$18/mês
- **Storage**: ~$1-5/mês
- **Total estimado**: ~$25-35/mês

## Comandos Úteis

```bash
# Ver outputs
terraform output

# Destruir infraestrutura
terraform destroy

# Verificar estado
terraform state list

# Atualizar módulos
terraform get -update
```

## Segurança

- Workload Identity habilitado
- Network policies disponíveis
- RBAC configurado
- Secrets gerenciados pelo Kubernetes