# AWS Variables
variable "aws_region" {
  description = "AWS region hosting the k3s cluster"
  type        = string
  default     = "eu-north-1"
}

variable "cluster_name" {
  description = "Name used by Cluster Autoscaler to discover node groups"
  type        = string
  default     = "travigo"
}

variable "vpc_id" {
  description = "VPC containing the k3s cluster"
  type        = string
}

variable "subnet_ids" {
  description = "Public subnets with Internet Gateway routes for autoscaled workers"
  type        = list(string)
}

variable "storage_subnet_id" {
  description = "Public subnet in the single AZ reserved for stateful storage workloads"
  type        = string
}

variable "k3s_server_private_ip" {
  description = "Private IP address of the k3s server"
  type        = string
}

variable "k3s_server_security_group_id" {
  description = "Security group ID attached to the k3s server"
  type        = string
}

variable "k3s_token" {
  description = "k3s join token for worker nodes"
  type        = string
  sensitive   = true
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

variable "cloudflare_root_domain" {
  description = "The root domain for the Cloudflare Zone"
  type        = string
}
