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

  version = "0.32.1"

  namespace = kubernetes_namespace.redis.metadata[0].name

  values = [
    yamlencode({
      auth = {
        password = random_password.redis-password.result
      }

      nodeSelector = {
        workload = "storage"
      }

      tolerations = [
        {
          key      = "workload"
          operator = "Equal"
          value    = "storage"
          effect   = "NoSchedule"
        }
      ]

      persistence = {
        storageClass = "ebs-gp3"
        enabled      = true
        size         = "12Gi"
      }

      resources = {
        requests = {
          cpu    = "2"
          memory = "12Gi"
        }
      }
    })
  ]
}
