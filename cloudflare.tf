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

# The random_id resource is used to generate a 35 character secret for the tunnel
resource "random_id" "tunnel_secret" {
  byte_length = 35
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "local_tunnel" {
  account_id = var.cloudflare_account_id
  name       = "travigo-gcp-kube"
  secret     = random_id.tunnel_secret.b64_std
}

# Create DNS entries for the cloudflare tunnel
resource "cloudflare_record" "root" {
  zone_id = local.cloudflare_zone_id
  name    = var.cloudflare_zone
  content = "${cloudflare_zero_trust_tunnel_cloudflared.local_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}
resource "cloudflare_record" "www" {
  zone_id = local.cloudflare_zone_id
  name    = "www.${var.cloudflare_zone}"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.local_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}
resource "cloudflare_record" "api" {
  zone_id = local.cloudflare_zone_id
  name    = "api.${var.cloudflare_zone}"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.local_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}
resource "cloudflare_record" "kibana" {
  zone_id = local.cloudflare_zone_id
  name    = "kibana.${var.cloudflare_zone}"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.local_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}
resource "cloudflare_record" "kube" {
  zone_id = local.cloudflare_zone_id
  name    = "kube.${var.cloudflare_zone}"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.local_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}
resource "cloudflare_record" "airflow" {
  zone_id = local.cloudflare_zone_id
  name    = "airflow.${var.cloudflare_zone}"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.local_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}
