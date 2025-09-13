# 🔐 GitHub Secrets - Configuração Completa

## Secrets Obrigatórios para CI/CD

Configure os seguintes secrets em: https://github.com/Vitorspk/multi-k8s/settings/secrets/actions

### 1. **GCP_PROJECT_ID** ✅ OBRIGATÓRIO
- **Valor**: `vschiavo-home` (ou seu project ID)
- **Descrição**: ID do projeto no Google Cloud Platform
- **Usado em**: Deploy workflow para identificar o projeto GCP

### 2. **GCP_SA_KEY** ✅ OBRIGATÓRIO
- **Valor**: Conteúdo completo do arquivo `service-account.json`
- **Como obter**:
  ```bash
  # Execute o script para criar a service account
  ./scripts/setup-gcp-service-account.sh
  
  # Copie o conteúdo do arquivo gerado
  cat service-account.json
  ```
- **Descrição**: Chave de autenticação da Service Account do GCP
- **Usado em**: Autenticação no Google Cloud

### 3. **DOCKER_USERNAME** ✅ OBRIGATÓRIO
- **Valor**: Seu nome de usuário do Docker Hub
- **Descrição**: Username para login no Docker Hub
- **Usado em**: Push das imagens Docker

### 4. **DOCKER_PASSWORD** ✅ OBRIGATÓRIO
- **Valor**: Sua senha ou Access Token do Docker Hub
- **Como criar Access Token**:
  1. Acesse: https://hub.docker.com/settings/security
  2. Clique em "New Access Token"
  3. Dê um nome descritivo (ex: "multi-k8s-github-actions")
  4. Copie o token gerado
- **Descrição**: Credencial para autenticação no Docker Hub
- **Usado em**: Login e push das imagens

### 5. **POSTGRES_PASSWORD** ✅ OBRIGATÓRIO
- **Valor**: Senha segura para o PostgreSQL
- **Como gerar senha segura**:
  ```bash
  # Opção 1: Use o script
  ./scripts/generate-postgres-password.sh
  
  # Opção 2: Gere manualmente
  openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
  ```
- **Descrição**: Senha do banco de dados PostgreSQL
- **Usado em**: Criação do secret no Kubernetes

## Secrets Opcionais (usam valores padrão se não configurados)

### 6. **GKE_CLUSTER_NAME** (Opcional)
- **Valor padrão**: `multi-k8s-cluster`
- **Descrição**: Nome do cluster GKE
- **Configure apenas se**: Usar nome diferente para o cluster

### 7. **GKE_ZONE** (Opcional)
- **Valor padrão**: `southamerica-east1-a`
- **Descrição**: Zona do GCP onde o cluster está localizado
- **Configure apenas se**: Usar zona diferente

### 8. **DEPLOYMENT_NAME** (Opcional)
- **Valor padrão**: `multi-k8s`
- **Descrição**: Nome base para os deployments
- **Configure apenas se**: Usar nome diferente

## 📝 Passo a Passo para Configurar

### Passo 1: Gerar Credenciais Localmente

```bash
# 1. Configure variáveis de ambiente
./scripts/setup-env-vars.sh
source .env.local

# 2. Crie a service account GCP
./scripts/setup-gcp-service-account.sh

# 3. Gere senha do PostgreSQL (se ainda não tiver)
./scripts/generate-postgres-password.sh
```

### Passo 2: Adicionar no GitHub

1. Acesse: **Settings → Secrets and variables → Actions**
2. Para cada secret, clique em **"New repository secret"**
3. Preencha:
   - **Name**: Nome do secret (ex: `GCP_PROJECT_ID`)
   - **Secret**: Valor do secret

### Passo 3: Verificar Configuração

Após adicionar todos os secrets, você pode verificar se estão configurados:

1. Vá em **Settings → Secrets and variables → Actions**
2. Você deve ver todos os 5 secrets obrigatórios listados:
   - ✅ GCP_PROJECT_ID
   - ✅ GCP_SA_KEY
   - ✅ DOCKER_USERNAME
   - ✅ DOCKER_PASSWORD
   - ✅ POSTGRES_PASSWORD

## 🚨 Importante

- **NUNCA** faça commit de credenciais no código
- **SEMPRE** use secrets para informações sensíveis
- **REVOGUE** imediatamente qualquer credencial exposta acidentalmente
- **USE** Access Tokens do Docker Hub ao invés de senha quando possível
- **MANTENHA** o arquivo `service-account.json` seguro e fora do repositório

## 🔄 Workflow Atualizado

O workflow `.github/workflows/deploy.yml` foi atualizado para usar todos os secrets:

```yaml
env:
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  GKE_CLUSTER: ${{ secrets.GKE_CLUSTER_NAME || 'multi-k8s-cluster' }}
  GKE_ZONE: ${{ secrets.GKE_ZONE || 'southamerica-east1-a' }}
  DEPLOYMENT_NAME: ${{ secrets.DEPLOYMENT_NAME || 'multi-k8s' }}
```

## ✅ Checklist Final

- [ ] GCP_PROJECT_ID configurado
- [ ] GCP_SA_KEY configurado (conteúdo do service-account.json)
- [ ] DOCKER_USERNAME configurado
- [ ] DOCKER_PASSWORD configurado (preferencialmente Access Token)
- [ ] POSTGRES_PASSWORD configurado (senha segura)
- [ ] Arquivo service-account.json está no .gitignore
- [ ] Nenhuma credencial está hardcoded no código

## 📊 Teste do Pipeline

Após configurar todos os secrets:

1. Faça um pequeno commit de teste
2. Push para master/main
3. Verifique em **Actions** se o workflow está executando
4. Monitore os logs para identificar qualquer problema

Se houver erros relacionados a autenticação, verifique:
- Os nomes dos secrets estão corretos
- Os valores não têm espaços extras ou quebras de linha indevidas
- A service account tem as permissões necessárias no GCP