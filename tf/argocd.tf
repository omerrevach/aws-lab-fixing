resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.51.6"

  # Expose the server as a ClusterIP service 
  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  # Enable ingress for ArgoCD
  set {
    name  = "server.ingress.enabled"
    value = "true"
  }

  set {
    name  = "server.ingress.ingressClassName"
    value = "alb"
  }

  # Hostname for ALB to route to (public domain)
  set {
    name  = "server.ingress.hostname"
    value = "argocd.stockpnl.com"
  }

  # Set the ingress path to "/" and use Prefix type so that all subpaths are served
  set {
    name  = "server.ingress.path"
    value = "/"
  }

  set {
    name  = "server.ingress.pathType"
    value = "Prefix"
  }

  # ALB ingress annotations
  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }

  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }

  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports"
    value = "[{\"HTTPS\":443}]"
  }

  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/backend-protocol"
    value = "HTTP"
  }

  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/backend-protocol-version"
    value = "HTTP1"
  }

  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/ssl-redirect"
    value = "443"
  }

  # Set the ACM certificate ARN (using sensitive interpolation)
  set_sensitive {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/certificate-arn"
    value = "arn:aws:acm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:certificate/${var.acm_cert_id}"
  }

  # Configure the ArgoCD URL (this tells ArgoCD its public URL)
  set {
    name  = "configs.cm.url"
    value = "https://${var.argocd_hostname}"
  }

  # Disable internal HTTPS redirect in ArgoCD (the ALB terminates SSL)
  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  depends_on = [module.eks_blueprints_addons]
}




data "kubernetes_ingress_v1" "argocd" {
  metadata {
    name      = "argocd-server"
    namespace = "argocd"
  }

  depends_on = [helm_release.argocd]
}

resource "null_resource" "wait_for_argocd_ingress" {
  depends_on = [helm_release.argocd]

  provisioner "local-exec" {
    command = <<EOT
      for i in {1..30}; do
        host=$(kubectl get ingress argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
        if [ ! -z "$host" ]; then
          echo "ALB Hostname: $host"
          exit 0
        fi
        echo "Waiting for ArgoCD ALB hostname..."
        sleep 10
      done
      echo "Timeout waiting for ArgoCD ALB hostname"
      exit 1
    EOT
    interpreter = ["bash", "-c"]
  }
}

resource "aws_route53_record" "argocd_dns" {
  depends_on = [null_resource.wait_for_argocd_ingress]

  zone_id = var.hosted_zone_id
  name    = var.argocd_hostname
  type    = "A"

  alias {
    name                   = data.kubernetes_ingress_v1.argocd.status[0].load_balancer[0].ingress[0].hostname
    zone_id                = var.alb_zone_id
    evaluate_target_health = false
  }
}


# Deplot the app with ArgoCD
resource "kubernetes_manifest" "argocd_app" {
  depends_on = [helm_release.argocd]

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "myapp"
      namespace = "argocd"
    }
    spec = {
      project = "default"

      source = {
        repoURL        = "https://github.com/omerrevach/aws-lab.git"
        targetRevision = "manifests"
        path           = "helm"
      }

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "default"
      }

      syncPolicy = {
        automated = {
          prune     = true
          selfHeal  = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }
}