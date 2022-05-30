resource "google_storage_bucket" "britbus-journey-history" {
  name          = "britbus-journey-history"
  location      = var.gcp_region

  uniform_bucket_level_access = true
}