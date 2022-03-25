resource "helm_release" "ingress-nginx" {
  name       = "ingress-nginx-controller"

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"

  set {
    name  = "controller.service.type"
    value = "ClusterIP"
  }
  set {
    name  = "defaultBackend.enabled"
    value = "true"
  }
}