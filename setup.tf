terraform {
  # backend "gcs" { 
  #   bucket  = "britbus-infra"
  #   prefix  = "terraform/ovh/state"
  # }
  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = "4.47.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.22.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.10.1"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "4.11.0"
    }
  }

  required_version = ">= 1.1"
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "cloudflare" {
  email      = var.cloudflare_email
  api_key    = var.cloudflare_token
}