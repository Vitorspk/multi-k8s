# The deployer service account is created manually via scripts/setup-gcp-permissions.sh
# We only reference it here, not create it

data "google_service_account" "deployer" {
  account_id = "multi-k8s-deployer"
  project    = var.project_id
}

# These IAM bindings are already configured via the setup script
# Keeping them here for documentation purposes only
# resource "google_project_iam_member" "deployer_roles" {
#   for_each = toset([
#     "roles/storage.admin",
#     "roles/container.admin",
#     "roles/compute.admin",
#     "roles/iam.serviceAccountUser",
#     "roles/resourcemanager.projectIamAdmin"
#   ])
#   
#   project = var.project_id
#   role    = each.key
#   member  = "serviceAccount:${data.google_service_account.deployer.email}"
# }

output "deployer_service_account_email" {
  value       = data.google_service_account.deployer.email
  description = "Email of the deployer service account"
}