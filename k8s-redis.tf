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

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "redis"

  version = "18.12.0"

  namespace = kubernetes_namespace.redis.metadata[0].name

  set {
    name  = "global.redis.password"
    value = random_password.redis-password.result
  }
  set {
    name = "master.persistence.enabled"
    value = "false"
  }
  set {
    name = "replica.persistence.enabled"
    value = "false"
  }
  set {
    name = "replica.replicaCount"
    value = "0"
  }
}