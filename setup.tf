terraform {
  backend "gcs" { 
    bucket  = "britbus-infra"
    prefix  = "terraform/state"
  }
  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = "4.15.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.9.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.4.1"
    }
  }

  required_version = ">= 1.1"
}

provider "google" {
  project = var.project_id
  region  = "europe-central2"
}

provider "kubernetes" {
  load_config_file = "false"

  host     = google_container_cluster.primary.endpoint

  client_certificate     = google_container_cluster.primary.master_auth.0.client_certificate
  client_key             = google_container_cluster.primary.master_auth.0.client_key
  cluster_ca_certificate = google_container_cluster.primary.master_auth.0.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    host     = google_container_cluster.primary.endpoint

    client_certificate     = base64decode(google_container_cluster.primary.master_auth.0.client_certificate)
    client_key             = base64decode(google_container_cluster.primary.master_auth.0.client_key)
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
  }
}