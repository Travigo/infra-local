resource "kubernetes_namespace" "redis" {
  metadata {
    name        = "redis"
    annotations = {}
    labels      = {}
  }
}

resource "random_password" "redis-password" {
  length  = 64
  special = false
}

resource "kubernetes_secret" "redis-password" {
  metadata {
    name = "redis-password"
  }

  data = {
    "password" = random_password.redis-password.result
  }

  type = "kubernetes.io/secret"
}

resource "helm_release" "redis" {
  name = "redis"

  repository = "oci://registry-1.docker.io/cloudpirates/"
  chart      = "redis"

  version = "0.37.12"

  namespace = kubernetes_namespace.redis.metadata[0].name

  values = [
    yamlencode({
      auth = {
        password = random_password.redis-password.result
      }

      persistence = {
        enabled      = true
        size         = "64Gi"
      }

      resources = {
        requests = {
          cpu    = "0.5"
          memory = "4Gi"
        }
      }
    })
  ]
}
