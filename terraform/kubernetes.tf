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
}

resource "kubernetes_secret" "pgpassword" {
  depends_on = [null_resource.configure_kubectl]
  
  metadata {
    name = "pgpassword"
  }
  
  data = {
    PGPASSWORD = var.postgres_password
  }
  
  type = "Opaque"
}

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
}

resource "null_resource" "wait_for_ingress" {
  depends_on = [null_resource.install_nginx_ingress]
  
  provisioner "local-exec" {
    command = "kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s"
  }
}