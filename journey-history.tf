resource "google_storage_bucket" "britbus-journey-history" {
  name          = "britbus-journey-history"
  location      = var.gcp_region
}

// Archiver 
resource "google_service_account" "realtime_archiver_service_account" {
  account_id   = "realtime-archiver"
  display_name = "Realtime Archiver"
}

resource "google_storage_bucket_access_control" "realtime_archiver_service_account" {
  bucket = google_storage_bucket.britbus-journey-history.name
  role   = "WRITER"
  entity = "user-${google_service_account.realtime_archiver_service_account.email}"
}

module "realtime_archiver_service_account_workload_identity" {
  source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version             = "24.1.0"

  use_existing_gcp_sa = true
  name                = google_service_account.realtime_archiver_service_account.account_id
  project_id          = var.gcp_project_id

  k8s_sa_name         = "realtime-archiver-service-account"

  # wait for the custom GSA to be created to force module data source read during apply
  # https://github.com/terraform-google-modules/terraform-google-kubernetes-engine/issues/1059
  depends_on = [google_service_account.realtime_archiver_service_account]
}

// Indexer
resource "google_service_account" "stats_indexer_service_account" {
  account_id   = "stats-indexer"
  display_name = "Stats Indexer"
}

resource "google_storage_bucket_access_control" "stats_indexer_service_account" {
  bucket = google_storage_bucket.britbus-journey-history.name
  role   = "READER"
  entity = "user-${google_service_account.stats_indexer_service_account.email}"
  
  depends_on = [google_service_account.stats_indexer_service_account]
}

module "stats_indexer_service_account_workload_identity" {
  source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version             = "24.1.0"

  use_existing_gcp_sa = true
  name                = google_service_account.stats_indexer_service_account.account_id
  project_id          = var.gcp_project_id

  k8s_sa_name         = "stats-indexer-service-account"

  # wait for the custom GSA to be created to force module data source read during apply
  # https://github.com/terraform-google-modules/terraform-google-kubernetes-engine/issues/1059
  depends_on = [google_service_account.stats_indexer_service_account]
}