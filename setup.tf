terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.16.1"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.48.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.1"
    }
  }

  required_version = ">= 1.5"
}

provider "aws" {
  region = var.aws_region
}

provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_token
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
