# resource "kubernetes_namespace" "mongodb" {
#   metadata {
#     name        = "mongodb"
#     annotations = {}
#     labels      = {}
#   }
# }

resource "helm_release" "mongodb-operator" {
  name       = "mongodb-operator"

  repository = "https://mongodb.github.io/helm-charts"
  chart      = "community-operator"

  # namespace = kubernetes_namespace.mongodb.metadata[0].name

  set {
    name  = "operator.resources.limits.cpu"
    value = "500m"
  }
  set {
    name  = "operator.resources.limits.memory"
    value = "1Gi"
  }
  set {
    name  = "operator.resources.requests.cpu"
    value = "10m"
  }
  set {
    name  = "operator.resources.requests.memory"
    value = "50Mi"
  }
}

resource "random_password" "mongodb-database-password" {
  length           = 64
  special          = false
}

resource "kubernetes_secret" "mongodb-database-password" {
  metadata {
    name      = "mongodb-database-password"
    # namespace = kubernetes_namespace.mongodb.metadata[0].name
  }

  data = {
    "password" = random_password.mongodb-database-password.result
  }

  type = "kubernetes.io/secret"
}

resource "kubernetes_manifest" "mongodb-database-crd" {
  depends_on = [
    helm_release.mongodb-operator,
  ]

  manifest = {
    apiVersion = "mongodbcommunity.mongodb.com/v1"
    kind       = "MongoDBCommunity"

    metadata = {
      name = "britbus-mongodb"
      # namespace = kubernetes_namespace.mongodb.metadata[0].name
      namespace = "default"
    }

    spec = {
      members = 1
      type = "ReplicaSet"
      version = "5.0.4"

      security = {
        authentication = {
          modes = [
            "SCRAM"
          ]
        }
      }

      users = [
        {
          name = "britbus"
          passwordSecretRef = {
            name = "mongodb-database-password"
          }
          scramCredentialsSecretName = "mongodb-scram"
          # TODO: This needs improving
          roles = [
            {
              name = "root"
              db = "admin"
            },
            {
              name = "root"
              db = "britbus"
            }
          ]
        }
      ]

      statefulSet = {
        spec = {
          template = {
            spec = {
              containers = [
                {
                  name = "mongod"
                  resources = {
                    limits = {
                      cpu = "2"
                      memory = "4Gi"
                    }
                    requests = {
                      cpu = "500m"
                      memory = "500M"
                    }
                  }
                },
                {
                  name = "mongodb-agent"
                  resources = {
                    limits = {
                      cpu = "2"
                      memory = "4Gi"
                    }
                    requests = {
                      cpu = "500m"
                      memory = "500M"
                    }
                  }
                }
              ]
            }
          }
        }
      }

      additionalMongodConfig = {
        "storage.wiredTiger.engineConfig.journalCompressor": "zlib"
      }
    }
  }
}