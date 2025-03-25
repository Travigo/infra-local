resource "helm_release" "mongodb-operator" {
  name       = "mongodb-operator"

  repository = "https://mongodb.github.io/helm-charts"
  chart      = "community-operator"

  version = "0.10.0"

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
    value = "1m"
  }
  set {
    name  = "operator.resources.requests.memory"
    value = "1Mi"
  }
}

resource "random_password" "mongodb-database-password" {
  length           = 64
  special          = false
}

resource "kubernetes_secret" "mongodb-database-password" {
  metadata {
    name      = "mongodb-database-password"
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
      name = "travigo-mongodb"
      namespace = "default"
    }

    spec = {
      members = 1
      type = "ReplicaSet"
      version = "7.0.12"

      security = {
        authentication = {
          modes = [
            "SCRAM"
          ]
        }
      }

      users = [
        {
          name = "travigo"
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
              db = "travigo"
            }
          ]
        }
      ]

      statefulSet = {
        spec = {
          volumeClaimTemplates = [
            {
              metadata = {
                name = "data-volume"
              }
              spec = {
                resources = {
                  requests = {
                    storage = "100Gi"
                  }
                }
              }
            },
            {
              metadata = {
                name = "logs-volume"
              }
              spec = {
                resources = {
                  requests = {
                    storage = "4Gi"
                  }
                }
              }
            }
          ]

          template = {
            spec = {
              containers = [
                {
                  name = "mongod"
                  resources = {
                    limits = {
                      cpu = "14"
                      memory = "10Gi"
                    }
                    requests = {
                      cpu = "0.1"
                      memory = "1Gi"
                    }
                  }
                },
                {
                  name = "mongodb-agent"
                  resources = {
                    limits = {
                      cpu = "4"
                      memory = "1Gi"
                    }
                    requests = {
                      cpu = "0.1"
                      memory = "1M"
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