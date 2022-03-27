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
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "3.11.0"
    }
  }

  required_version = ">= 1.1"
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "kubernetes" {
  host     = "https://${google_container_cluster.primary.endpoint}"

  client_certificate     = base64decode(google_container_cluster.primary.master_auth.0.client_certificate)
  client_key             = base64decode(google_container_cluster.primary.master_auth.0.client_key)
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host     = "https://${google_container_cluster.primary.endpoint}"

    client_certificate     = base64decode(google_container_cluster.primary.master_auth.0.client_certificate)
    client_key             = base64decode(google_container_cluster.primary.master_auth.0.client_key)
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
  }
}

provider "cloudflare" {
  email      = var.cloudflare_email
  account_id = var.cloudflare_account_id
  api_key    = var.cloudflare_token
}