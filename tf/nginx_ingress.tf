resource "helm_release" "ingress_nginx" {
  depends_on = [module.eks_blueprints_addons]
  name       = "ingress-nginx"
  chart      = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  namespace  = "ingress"
  create_namespace = true

  set {
    name  = "controller.service.type"
    value = "ClusterIP"  # Keep as ClusterIP as per requirement
  }

  # Add proper tolerations for Fargate
  set {
    name  = "controller.tolerations[0].key"
    value = "eks.amazonaws.com/compute-type"
  }

  set {
    name  = "controller.tolerations[0].value"
    value = "fargate"
  }

  set {
    name  = "controller.tolerations[0].operator"
    value = "Equal"
  }

  set {
    name  = "controller.tolerations[0].effect"
    value = "NoSchedule"
  }

  # Add nodeSelector for Fargate
  set {
    name  = "controller.nodeSelector.eks\\.amazonaws\\.com/compute-type"
    value = "fargate"
  }

  # Configure admission webhook to work with Fargate
  set {
    name  = "controller.admissionWebhooks.patch.tolerations[0].key"
    value = "eks.amazonaws.com/compute-type"
  }

  set {
    name  = "controller.admissionWebhooks.patch.tolerations[0].value"
    value = "fargate"
  }

  set {
    name  = "controller.admissionWebhooks.patch.tolerations[0].operator"
    value = "Equal"
  }

  set {
    name  = "controller.admissionWebhooks.patch.tolerations[0].effect"
    value = "NoSchedule"
  }

  # Configure admission webhook with nodeSelector
  set {
    name  = "controller.admissionWebhooks.patch.nodeSelector.eks\\.amazonaws\\.com/compute-type"
    value = "fargate"
  }
  
  # Add resources limits for Fargate
  set {
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "128Mi"
  }

  # Critical setting: make it work properly with admission jobs
  set {
    name  = "controller.admissionWebhooks.patch.image.registry"
    value = "registry.k8s.io"
  }

  set {
    name  = "controller.admissionWebhooks.patch.image.image"
    value = "ingress-nginx/kube-webhook-certgen"
  }

  set {
    name  = "controller.admissionWebhooks.patch.image.tag"
    value = "v1.4.0"
  }

  set {
    name  = "controller.admissionWebhooks.patch.image.digest"
    value = "sha256:44d1d0e9f19c63f58b380c5fddaca7cf22c7cee564adeff365225a5df5ef3334"
  }
  
  # Job specific tolerations and nodeSelectors
  set {
    name  = "controller.admissionWebhooks.patch.tolerations[0].key"
    value = "eks.amazonaws.com/compute-type"
  }

  set {
    name  = "controller.admissionWebhooks.patch.tolerations[0].value"
    value = "fargate"
  }

  set {
    name  = "controller.admissionWebhooks.patch.tolerations[0].operator"
    value = "Equal"
  }

  set {
    name  = "controller.admissionWebhooks.patch.tolerations[0].effect"
    value = "NoSchedule"
  }

  # Make sure the jobs get scheduled on Fargate nodes
  set {
    name  = "controller.admissionWebhooks.patch.nodeSelector.eks\\.amazonaws\\.com/compute-type"
    value = "fargate"
  }

  # Ensure the admission jobs can complete
  set {
    name  = "controller.admissionWebhooks.patch.priorityClassName"
    value = ""
  }

  set {
    name  = "controller.admissionWebhooks.patch.podAnnotations.eks\\.amazonaws\\.com/fargate-profile"
    value = "default"
  }

  set {
    name  = "controller.extraArgs.enable-ssl-passthrough"
    value = ""
  }

}

resource "time_sleep" "wait_for_nginx" {
  depends_on = [helm_release.ingress_nginx]
  create_duration = "45s"  # Increased to give more time for pods to start
}

data "aws_caller_identity" "current" {}

data "kubernetes_namespace" "ingress" {
  metadata {
    name = "ingress"
  }
}

resource "kubernetes_ingress_v1" "nginx_alb" {
  metadata {
    name      = "nginx-ingress"
    namespace = "ingress"
    annotations = {
      "kubernetes.io/ingress.class"                      = "alb"
      "alb.ingress.kubernetes.io/scheme"                 = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"            = "ip"
      "alb.ingress.kubernetes.io/listen-ports"           = "[{\"HTTP\":80}, {\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/backend-protocol"       = "HTTP"
      "alb.ingress.kubernetes.io/healthcheck-path"       = "/healthz"
      "alb.ingress.kubernetes.io/certificate-arn"        = "arn:aws:acm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:certificate/${var.acm_cert_id}"

      "alb.ingress.kubernetes.io/ssl-redirect"           = "443"
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      host = var.nginx_hostname
      http {
        path {
          path      = "/*"
          path_type = "ImplementationSpecific"
          backend {
            service {
              name = "ingress-nginx-controller"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
  depends_on = [
    helm_release.ingress_nginx
  ]

}

data "kubernetes_ingress_v1" "alb_ingress" {
  metadata {
    name      = kubernetes_ingress_v1.nginx_alb.metadata[0].name
    namespace = kubernetes_ingress_v1.nginx_alb.metadata[0].namespace
  }

  depends_on = [kubernetes_ingress_v1.nginx_alb]
}

resource "null_resource" "wait_for_ingress_ready" {
  depends_on = [kubernetes_ingress_v1.nginx_alb]

  provisioner "local-exec" {
    command = <<EOT
      for i in {1..30}; do
        HOST=$(kubectl get ingress nginx-ingress -n ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
        if [ "$HOST" != "" ]; then
          echo "ALB ready: $HOST"
          exit 0
        fi
        echo "Waiting for ALB..."
        sleep 10
      done
      echo "Timeout waiting for ALB hostname"
      exit 1
    EOT
    interpreter = ["bash", "-c"]
  }
}

resource "aws_route53_record" "stockpnl_com" {
  depends_on = [null_resource.wait_for_ingress_ready]

  zone_id = var.hosted_zone_id
  name    = var.nginx_hostname
  type    = "A"

  alias {
    name                   = kubernetes_ingress_v1.nginx_alb.status[0].load_balancer[0].ingress[0].hostname
    zone_id                = var.alb_zone_id
    evaluate_target_health = false
  }
}