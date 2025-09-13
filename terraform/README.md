# Terraform Infrastructure for Multi-K8s

This directory contains Terraform configuration for provisioning GKE infrastructure.

## Prerequisites

1. Google Cloud SDK (`gcloud`) installed and authenticated
2. Terraform 1.0+ installed
3. GCP Project with billing enabled
4. Required APIs enabled (Container, Compute, IAM)

## Initial Setup

### 1. Create Terraform State Bucket

Before running Terraform for the first time, you need to create the GCS bucket for storing Terraform state:

```bash
# From the project root directory
./scripts/setup-terraform-backend.sh
```

Or manually:

```bash
gsutil mb -p vschiavo-home -l southamerica-east1 gs://vschiavo-home-terraform-state
gsutil versioning set on gs://vschiavo-home-terraform-state
```

### 2. Initialize Terraform

```bash
cd terraform
terraform init
```

### 3. Create Infrastructure

```bash
# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

## GitHub Actions Setup

The infrastructure can also be managed via GitHub Actions:

1. Go to Actions tab in GitHub
2. Select "Setup GKE Infrastructure" workflow
3. Click "Run workflow"
4. Choose action: plan, apply, or destroy

The workflow will automatically create the state bucket if it doesn't exist.

## Required Variables

- `project_id`: GCP Project ID (default: vschiavo-home)
- `region`: GCP Region (default: southamerica-east1)
- `zone`: GCP Zone (default: southamerica-east1-a)
- `docker_username`: Docker Hub username (sensitive)
- `postgres_password`: PostgreSQL password (sensitive)

## Resources Created

- GKE Cluster with Workload Identity
- VPC Network and Subnet
- Node Pool with autoscaling
- Service Account for GKE
- Global IP address for Ingress

## Destroying Infrastructure

To tear down all resources:

```bash
terraform destroy
```

Or via GitHub Actions, select "destroy" as the action.