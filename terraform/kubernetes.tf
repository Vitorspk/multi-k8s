resource "null_resource" "configure_kubectl" {
  depends_on = [google_container_cluster.primary]

  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${var.zone} --project ${var.project_id}"
  }
}

resource "kubernetes_namespace" "nginx_ingress" {
  depends_on = [null_resource.configure_kubectl]

  metadata {
    name = "ingress-nginx"
  }

  # Add finalizers configuration to help with cleanup
  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }
}

# PostgreSQL secret removed - now managed via GCP Secret Manager
# The secrets are automatically synced from GCP Secret Manager during deployment
# See scripts/manage-secrets.sh and scripts/sync-secrets.py

resource "null_resource" "install_nginx_ingress" {
  depends_on = [
    kubernetes_namespace.nginx_ingress,
    null_resource.configure_kubectl
  ]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

      kubectl patch service ingress-nginx-controller \
        -n ingress-nginx \
        -p '{"spec":{"loadBalancerIP":"${google_compute_global_address.ingress_ip.address}"}}'
    EOT
  }

  # Clean up nginx ingress resources before destroying
  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml --ignore-not-found=true || true

      # Force delete the namespace if it's stuck
      kubectl delete namespace ingress-nginx --grace-period=0 --force --ignore-not-found=true || true
    EOT
    on_failure = continue
  }
}

resource "null_resource" "wait_for_ingress" {
  depends_on = [null_resource.install_nginx_ingress]

  provisioner "local-exec" {
    command = "kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s"
  }
}