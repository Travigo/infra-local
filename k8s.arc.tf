resource "kubernetes_namespace" "arc-system" {
  metadata {
    name        = "arc-system"
    annotations = {}
    labels      = {}
  }
}

resource "kubernetes_namespace" "arc-runners" {
  metadata {
    name        = "arc-runners"
    annotations = {}
    labels      = {}
  }
}

resource "helm_release" "arc-operator" {
  name       = "arc"

  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set-controller"

  version = "0.12.1"

  namespace = kubernetes_namespace.arc-system.metadata[0].name
}

resource "helm_release" "arc-runner" {
  name       = "arc"

  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set"

  version = "0.12.1"

  namespace = kubernetes_namespace.arc-runners.metadata[0].name

  set {
    name = "githubConfigUrl"
    value = "https://github.com/travigo"
  }

  set {
    name = "githubConfigSecret"
    value = "github-pat"
  }
}

resource "kubernetes_cluster_role_binding" "runner_perms" {
  metadata {
    name = "arc-runner-perms"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "arc-gha-rs-no-permission"
    namespace = kubernetes_namespace.arc-runners.metadata[0].name
  }
}
