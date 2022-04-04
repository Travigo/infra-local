resource "kubernetes_namespace" "ingress-nginx" {
  metadata {
    name        = "ingress-nginx"
    annotations = {}
    labels      = {}
  }
}

resource "helm_release" "ingress-nginx" {
  name       = "ingress-nginx"

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"

  namespace = kubernetes_namespace.ingress-nginx.metadata[0].name

  set {
    name  = "controller.service.type"
    value = "ClusterIP"
  }
  set {
    name  = "defaultBackend.enabled"
    value = "true"
  }
}