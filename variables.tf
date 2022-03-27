# GCP variables
variable "gcp_project_id" {
  description = "Google Cloud Platform Project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region name"
  type        = string
  default     = "europe-central2"
}

variable "gcp_zone" {
  description = "GCP zone name"
  type        = string
  default     = "europe-central2-a"
}

# Cloudflare Variables
variable "cloudflare_zone" {
  description = "The Cloudflare Zone to use"
  type        = string
}

variable "cloudflare_account_id" {
  description = "The Cloudflare UUID for the Account the Zone lives in"
  type        = string
  sensitive   = true
}

variable "cloudflare_email" {
  description = "The Cloudflare user"
  type        = string
  sensitive   = true
}

variable "cloudflare_token" {
  description = "The Cloudflare users API token."
  type        = string
}