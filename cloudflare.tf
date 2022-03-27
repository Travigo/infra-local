# Lookup for zone ID from the zone name
data "cloudflare_zones" "zones" {
  filter {
    name        = var.cloudflare_zone
    lookup_type = "exact"
    status      = "active"
  }
}

locals {
  cloudflare_zone_id = lookup(element(data.cloudflare_zones.zones.zones, 0), "id")
}

# data "cloudflare_api_token_permission_groups" "all" {}

# # Token allowed to edit DNS entries for specific zone.
# resource "cloudflare_api_token" "zone_dns_edit" {
#   name = "terraform-gke-dns-edit"

#   policy {
#     permission_groups = [
#       data.cloudflare_api_token_permission_groups.all.permissions["DNS Write"],
#     ]
#     resources = {
#       "com.cloudflare.api.account.zone.${local.cloudflare_zone_id}" = "*"
#     }
#   }
# }

# The random_id resource is used to generate a 35 character secret for the tunnel
resource "random_id" "tunnel_secret" {
  byte_length = 35
}

# A Named Tunnel resource called terraform-gcp-gke
resource "cloudflare_argo_tunnel" "gke_tunnel" {
  account_id = var.cloudflare_account_id
  name       = "britbus-gcp-gke"
  secret     = random_id.tunnel_secret.b64_std
}

# Create DNS entries for the cloudflare tunnel
resource "cloudflare_record" "root" {
  zone_id = local.cloudflare_zone_id
  name    = var.cloudflare_zone
  value   = "${cloudflare_argo_tunnel.gke_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}
resource "cloudflare_record" "api" {
  zone_id = local.cloudflare_zone_id
  name    = "api.${var.cloudflare_zone}"
  value   = "${cloudflare_argo_tunnel.gke_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}