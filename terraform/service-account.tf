resource "google_service_account" "deployer" {
  account_id   = "multi-k8s-deployer"
  display_name = "Multi-K8s Deployer Service Account"
  description  = "Service account for GitHub Actions deployments"
}

resource "google_project_iam_member" "deployer_roles" {
  for_each = toset([
    "roles/storage.admin",
    "roles/container.admin",
    "roles/compute.admin",
    "roles/iam.serviceAccountUser",
    "roles/resourcemanager.projectIamAdmin"
  ])
  
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_service_account_key" "deployer_key" {
  service_account_id = google_service_account.deployer.name
}

output "deployer_service_account_email" {
  value       = google_service_account.deployer.email
  description = "Email of the deployer service account"
}

output "deployer_service_account_key" {
  value       = google_service_account_key.deployer_key.private_key
  description = "Private key for the deployer service account (base64 encoded)"
  sensitive   = true
}