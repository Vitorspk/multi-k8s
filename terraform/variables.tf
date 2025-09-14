variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "vschiavo-home"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "southamerica-east1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "southamerica-east1-a"
}

variable "cluster_name" {
  description = "GKE Cluster name"
  type        = string
  default     = "multi-k8s"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "prod"
}

variable "node_count" {
  description = "Initial number of nodes"
  type        = number
  default     = 1
}

variable "min_node_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 3
}

variable "machine_type" {
  description = "Machine type for nodes"
  type        = string
  default     = "e2-small"
}

variable "preemptible" {
  description = "Use preemptible nodes for cost saving"
  type        = bool
  default     = true
}

# Variable removed - now using GCP Container Registry instead of Docker Hub
# variable "docker_username" {
#   description = "Docker Hub username"
#   type        = string
#   sensitive   = true
# }

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}