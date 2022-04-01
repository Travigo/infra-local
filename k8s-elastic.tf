resource "kubernetes_namespace" "elastic" {
  metadata {
    name        = "elastic"
    annotations = {}
    labels      = {}
  }
}

resource "helm_release" "elasticsearch" {
  name       = "elasticsearch"

  repository = "https://helm.elastic.co"
  chart      = "elasticsearch"

  version = "7.17.1"

  namespace = kubernetes_namespace.elastic.metadata[0].name

  set {
    name  = "esJavaOpts"
    value = "-Xmx128m -Xms128m"
  }
  set {
    name  = "antiAffinity"
    value = "soft"
  }

  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "resources.requests.memory"
    value = "512M"
  }
  set {
    name  = "resources.limits.cpu"
    value = "1000m"
  }
  set {
    name  = "resources.limits.memory"
    value = "512M"
  }

  set {
    name = "replicas"
    value = "1"
  }
  set {
    name = "minimumMasterNodes"
    value = "1"
  }

  # set {
  #   name  = "volumeClaimTemplate.accessModes"
  #   value = "ReadWriteOnce"
  # }
  set {
    name  = "volumeClaimTemplate.resources.requests.storage"
    value = "512M"
  }
}


resource "helm_release" "kibana" {
  name       = "kibana"

  repository = "https://helm.elastic.co"
  chart      = "kibana"

  version = "7.17.1"

  namespace = kubernetes_namespace.elastic.metadata[0].name

  set {
    name  = "ingress.enabled"
    value = "true"
  }
  set {
    name  = "ingress.hosts[0].host"
    value = "kibana.britbus.app"
  }
  set {
    name  = "ingress.hosts[0].paths[0].path"
    value = "/"
  }

  set {
    name  = "resources.requests.cpu"
    value = "10m"
  }
  set {
    name  = "resources.requests.memory"
    value = "1Gi"
  }
  set {
    name  = "resources.limits.cpu"
    value = "500m"
  }
  set {
    name  = "resources.limits.memory"
    value = "2Gi"
  }

  set {
    name = "readinessProbe.initialDelaySeconds"
    value = "60"
  }
}

resource "helm_release" "metricbeat" {
  name       = "metricbeat"

  repository = "https://helm.elastic.co"
  chart      = "metricbeat"

  version = "7.17.1"

  namespace = kubernetes_namespace.elastic.metadata[0].name

  set {
    name  = "deployment.requests.cpu"
    value = "10m"
  }
  set {
    name  = "deployment.requests.memory"
    value = "100Mi"
  }
  set {
    name  = "deployment.limits.cpu"
    value = "500m"
  }
  set {
    name  = "deployment.limits.memory"
    value = "200Mi"
  }
}