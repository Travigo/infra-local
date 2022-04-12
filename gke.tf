# GKE cluster
resource "google_container_cluster" "primary" {
  name     = "${var.gcp_project_id}-gke"
  location = var.gcp_zone
  
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.primary-subnet.name

  ip_allocation_policy {
    cluster_ipv4_cidr_block = ""
    services_ipv4_cidr_block = ""
  }

  # This enables data-plane v2 which does support network_policy
  datapath_provider = "ADVANCED_DATAPATH"

  min_master_version = "1.22"

  # TODO: get rid of this and do proper RBAC (Google groups for RBAC & Workload Identity)
  enable_legacy_abac = true
  master_auth {
    client_certificate_config {
      issue_client_certificate = true
    }
  }
}

# Spot Nodes
resource "google_container_node_pool" "spot_nodes" {
  name       = "${google_container_cluster.primary.name}-spot-node-pool"
  location   = var.gcp_zone
  cluster    = google_container_cluster.primary.name
  node_count = 2

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = var.gcp_project_id
    }

    spot  = true

    machine_type = "e2-standard-2"
    disk_size_gb = 16

    tags         = ["gke-node", "${var.gcp_project_id}-gke"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}