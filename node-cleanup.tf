# K3s does not run the AWS cloud-controller-manager, so an EC2 instance
# terminated by Cluster Autoscaler remains as an Unreachable Node object. This
# narrowly scoped job removes AWS-backed Nodes once they are either marked for
# deletion by Cluster Autoscaler or have remained Unknown for ten minutes.
resource "kubernetes_service_account_v1" "cluster_autoscaler_node_cleanup" {
  metadata {
    name      = "cluster-autoscaler-node-cleanup"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_v1" "cluster_autoscaler_node_cleanup" {
  metadata {
    name = "cluster-autoscaler-node-cleanup"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "delete"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "cluster_autoscaler_node_cleanup" {
  metadata {
    name = "cluster-autoscaler-node-cleanup"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.cluster_autoscaler_node_cleanup.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.cluster_autoscaler_node_cleanup.metadata[0].name
    namespace = kubernetes_service_account_v1.cluster_autoscaler_node_cleanup.metadata[0].namespace
  }
}

resource "kubernetes_cron_job_v1" "cluster_autoscaler_node_cleanup" {
  metadata {
    name      = "cluster-autoscaler-node-cleanup"
    namespace = "kube-system"
  }

  spec {
    schedule                      = "*/2 * * * *"
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 3

    job_template {
      metadata {}

      spec {
        template {
          metadata {}

          spec {
            service_account_name = kubernetes_service_account_v1.cluster_autoscaler_node_cleanup.metadata[0].name
            restart_policy       = "OnFailure"
            priority_class_name  = "system-cluster-critical"

            node_selector = {
              "kubernetes.io/os"                      = "linux"
              "node-role.kubernetes.io/control-plane" = "true"
            }

            toleration {
              key      = "node-role.kubernetes.io/control-plane"
              operator = "Exists"
              effect   = "NoSchedule"
            }

            container {
              name    = "cleanup"
              image   = "bitnami/kubectl@sha256:85439b3b6f334b773477c13068e6a1315ca7e2a0b1c2dd762cccf3f4e4d4687b"
              command = ["/bin/sh", "-ec"]
              args = [<<-EOT
                kubectl get nodes -o name | while read -r node; do
                  name="$${node#node/}"
                  unschedulable="$(kubectl get node "$${name}" -o jsonpath='{.spec.unschedulable}')"
                  taints="$(kubectl get node "$${name}" -o jsonpath='{range .spec.taints[*]}{.key}={.effect}{","}{end}')"
                  ready="$(kubectl get node "$${name}" -o jsonpath='{range .status.conditions[?(@.type=="Ready")]}{.status}{end}')"
                  provider_id="$(kubectl get node "$${name}" -o jsonpath='{.spec.providerID}')"
                  unknown_since="$(kubectl get node "$${name}" -o jsonpath='{range .status.conditions[?(@.type=="Ready")]}{.lastTransitionTime}{end}')"

                  if [ "$${ready}" != "Unknown" ]; then
                    continue
                  fi

                  case "$${provider_id}" in
                    aws:///*) ;;
                    *) continue ;;
                  esac

                  case "$${taints}" in
                    *ToBeDeletedByClusterAutoscaler=NoSchedule*) ;;
                    *)
                      now="$(date -u +%s)"
                      transitioned="$(date -u -d "$${unknown_since}" +%s)"
                      [ "$(( $${now} - $${transitioned} ))" -ge 600 ] || continue
                      ;;
                  esac

                  kubectl get pods -A --field-selector "spec.nodeName=$${name}" \
                    -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' |
                    while read -r namespace pod; do
                      [ -z "$${pod}" ] || kubectl delete pod -n "$${namespace}" "$${pod}" --grace-period=0 --force
                    done

                  kubectl delete node "$${name}" --wait=false
                done
              EOT
              ]
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_cluster_role_binding_v1.cluster_autoscaler_node_cleanup]
}
