# VPC
resource "google_compute_network" "vpc" {
  name                    = "${var.project_id}-vpc"
  auto_create_subnetworks = "false"
}

# Main Warsaw Subnet
resource "google_compute_subnetwork" "warsaw-subnet" {
  name          = "${var.project_id}-warsaw-subnet"
  region        = "europe-central2"
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.10.0.0/24"
}