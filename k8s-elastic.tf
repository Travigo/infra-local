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
      version = "8.5.3"
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
                    requests = {
                      memory = "8Gi"
                      cpu = "2"
                    },
                    limits = {
                      memory = "8Gi"
                      cpu = "4"
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
      version = "8.5.3"
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

# resource "kubernetes_manifest" "metricbeat" {
#   field_manager {
#     force_conflicts = true
#   }
#   depends_on = [
#     helm_release.eck-operator,
#     kubernetes_manifest.elasticsearch-primary
#   ]

#   manifest = {
#     apiVersion = "beat.k8s.elastic.co/v1beta1"
#     kind       = "Beat"

#     metadata = {
#       name = "metricbeat"
#       namespace = kubernetes_namespace.elastic.metadata[0].name
#     }

#     spec = {
#       version = "8.1.3"
#       type = "metricbeat"

#       elasticsearchRef = {
#         name = "primary"
#       }
#       kibanaRef = {
#         name = "kibana"
#       }

#       "config" = {
#         "metricbeat" = {
#           "autodiscover" = {
#             "providers" = {
#               "hints" = {
#                 "default_config" = {}

#                 "enabled" = "true"
#               }

#               # "node" = "${NODE_NAME}"

#               "type" = "kubernetes"
#             }
#           }

#           "modules" = {
#             "metricsets" = ["cpu", "load", "memory", "network", "process", "process_summary"]

#             "module" = "system"

#             "period" = "10s"

#             "process" = {
#               "include_top_n" = {
#                 "by_cpu" = 5

#                 "by_memory" = 5
#               }
#             }

#             "processes" = [".*"]
#           }

#           "modules" = {
#             "metricsets" = ["filesystem", "fsstat"]

#             "module" = "system"

#             "period" = "1m"

#             "processors" = {
#               "drop_event" = {
#                 "when" = {
#                   "regexp" = {
#                     "system" = {
#                       "filesystem" = {
#                         "mount_point" = "^/(sys|cgroup|proc|dev|etc|host|lib)($|/)"
#                       }
#                     }
#                   }
#                 }
#               }
#             }
#           }

#           "modules" = {
#             "bearer_token_file" = "/var/run/secrets/kubernetes.io/serviceaccount/token"

#             # "hosts" = ["https://${NODE_NAME}:10250"]

#             "metricsets" = ["node", "system", "pod", "container", "volume"]

#             "module" = "kubernetes"

#             # "node" = "${NODE_NAME}"

#             "period" = "10s"

#             "ssl" = {
#               "verification_mode" = "none"
#             }
#           }
#         }

#         "processors" = {
#           "add_cloud_metadata" = {}
#           "add_host_metadata" = {}
#         }
#       }

#       "daemonSet" = {
#         "podTemplate" = {
#           "spec" = {
#             "automountServiceAccountToken" = true

#             "containers" = [{
#               "args" = ["-e", "-c", "/etc/beat.yml", "-system.hostfs=/hostfs"]

#               "env" = [{
#                 "name" = "NODE_NAME"

#                 "valueFrom" = {
#                   "fieldRef" = {
#                     "fieldPath" = "spec.nodeName"
#                   }
#                 }
#               }]

#               "name" = "metricbeat"

#               "volumeMounts" = [
#                 # {
#                 #   "mountPath" = "/hostfs/sys/fs/cgroup"

#                 #   "name" = "cgroup"
#                 # },
#                 # {
#                 #   "mountPath" = "/var/run/docker.sock"

#                 #   "name" = "dockersock"
#                 # },
#                 # {
#                 #   "mountPath" = "/hostfs/proc"

#                 #   "name" = "proc"
#                 # }
#               ]

#               "dnsPolicy" = "ClusterFirstWithHostNet"

#               "hostNetwork" = true

#               "securityContext" = {
#                 "runAsUser" = 0
#               }

#               "serviceAccountName" = "metricbeat"

#               "terminationGracePeriodSeconds" = 30

#               "volumes" = [
#                 {
#                   "hostPath" = {
#                     "path" = "/sys/fs/cgroup"
#                   }

#                   "name" = "cgroup"
#                 },
#                 {
#                   "hostPath" = {
#                     "path" = "/var/run/docker.sock"
#                   }

#                   "name" = "dockersock"
#                 },
#                 {
#                   "hostPath" = {
#                     "path" = "/proc"
#                   }

#                   "name" = "proc"
#                 }
#               ]
#             }]
#           }
#         }
#       }
#     }
#   }
# }

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
