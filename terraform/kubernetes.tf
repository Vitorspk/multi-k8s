resource "null_resource" "configure_kubectl" {
  depends_on = [google_container_cluster.primary]

  provisioner "local-exec" {
    command = <<-EOT
      gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${var.zone} --project ${var.project_id}
      echo "Kubeconfig updated for cluster ${google_container_cluster.primary.name}"
    EOT
  }

  # Force recreation when cluster changes
  triggers = {
    cluster_id = google_container_cluster.primary.id
  }
}


resource "null_resource" "install_nginx_ingress" {
  depends_on = [
    null_resource.configure_kubectl,
    google_container_node_pool.primary_nodes
  ]

  provisioner "local-exec" {
    command = <<-EOT
      # Ensure kubectl is configured
      gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${var.zone} --project ${var.project_id}

      # Wait for cluster to be ready
      sleep 10

      # Create namespace if it doesn't exist
      kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -

      # Apply NGINX ingress controller
      kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

      # Wait for the ingress controller namespace to be ready
      kubectl wait --namespace ingress-nginx \
        --for=condition=established \
        --timeout=60s \
        crd/ingressclasses.networking.k8s.io || true

      # Patch the service with the static IP
      kubectl patch service ingress-nginx-controller \
        -n ingress-nginx \
        -p '{"spec":{"loadBalancerIP":"${google_compute_global_address.ingress_ip.address}"}}'
    EOT
  }

  # Clean up nginx ingress resources before destroying
  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      # Delete NGINX ingress resources
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
    command = <<-EOT
      # Ensure kubectl is configured
      gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${var.zone} --project ${var.project_id}

      # Wait for the ingress controller to be ready
      kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s || true
    EOT
  }

  # Force recreation when nginx installation changes
  triggers = {
    nginx_install = null_resource.install_nginx_ingress.id
  }
}