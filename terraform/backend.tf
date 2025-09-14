# This file is auto-generated. Do not edit directly.
# To change backend configuration, update backend.tf.template and re-run setup

terraform {
  backend "gcs" {
    bucket = "your-gcp-project-id-terraform-state"
    prefix = "multi-k8s/state"
  }
}