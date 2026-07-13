resource "kubernetes_namespace" "redis" {
  metadata {
    name        = "redis"
    annotations = {}
    labels      = {}
  }
}

resource "random_password" "redis-password" {
  length           = 64
  special          = false
}

resource "kubernetes_secret" "redis-password" {
  metadata {
    name      = "redis-password"
  }

  data = {
    "password" = random_password.redis-password.result
  }

  type = "kubernetes.io/secret"
}

resource "helm_release" "redis" {
  name       = "redis"

  repository = "oci://registry-1.docker.io/cloudpirates/"
  chart      = "redis"

  version = "0.32.1"

  namespace = kubernetes_namespace.redis.metadata[0].name

  set {
    name  = "auth.password"
    value = random_password.redis-password.result
  }
  set {
    name = "persistence.enabled"
    value = "true"
  }
  set {
    name = "persistence.size"
    value = "15Gi"
  }
}