resource "kubernetes_namespace" "elastic" {
  metadata {
    name        = "elastic"
    annotations = {}
    labels      = {}
  }
}

resource "helm_release" "eck-operator" {
  name       = "elasticsearch"

  repository = "https://helm.elastic.co"
  chart      = "eck-operator"

  namespace = kubernetes_namespace.elastic.metadata[0].name
}

resource "kubernetes_manifest" "elasticsearch-primary" {
  field_manager {
    force_conflicts = true
  }
  depends_on = [
    helm_release.eck-operator,
  ]

  manifest = {
    apiVersion = "elasticsearch.k8s.elastic.co/v1"
    kind       = "Elasticsearch"

    metadata = {
      name = "primary"
      namespace = kubernetes_namespace.elastic.metadata[0].name
    }

    spec = {
      version = "8.1.3"
      nodeSets = [
        {
          name = "primary"
          count = 1
          config = {
            "node.roles" = ["master", "data", "ingest", "ml"]
            "node.store.allow_mmap" = false
          }

          podTemplate = {
            spec = {
              containers = [
                {
                  name = "elasticsearch"
                  resources = {
                    limits = {
                      memory = "2Gi"
                      cpu = "1"
                    }
                  }
                }
              ]
            }
          }

          volumeClaimTemplates = [
            {
              metadata = {
                name = "elasticsearch-data"
              }

              spec = {
                accessModes = [
                  "ReadWriteOnce"
                ]
                resources = {
                  requests = {
                    storage = "2Gi"
                  }
                }
              }
            }
          ]
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "kibana-primary" {
  field_manager {
    force_conflicts = true
  }
  depends_on = [
    helm_release.eck-operator,
    kubernetes_manifest.elasticsearch-primary
  ]

  manifest = {
    apiVersion = "kibana.k8s.elastic.co/v1"
    kind       = "Kibana"

    metadata = {
      name = "kibana"
      namespace = kubernetes_namespace.elastic.metadata[0].name
    }

    spec = {
      version = "8.1.3"
      count = 1
      elasticsearchRef = {
        name = "primary"
      }
      config = {
        "server.publicBaseUrl" = "https://kibana.britbus.app"
      }
    }
  }
}

resource "kubernetes_ingress_v1" "kibana_ingress" {
  metadata {
    name = "kibana-ingress"
    namespace = kubernetes_namespace.elastic.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/proxy-ssl-verify" = "false"
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "kibana.britbus.app"

      http {
        path {
          backend {
            service {
              name = "kibana-kb-http"
              port {
                number = 5601
              }
            }    
          }

          path = "/"
        }
      }
    }
  }
}
