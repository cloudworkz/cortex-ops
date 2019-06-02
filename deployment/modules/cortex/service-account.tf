# Create Service Account
resource "google_service_account" "sa_cortex" {
  account_id   = "sa-cortex"
  display_name = "Cortex service account"
  project      = "${var.bigtable_project}"
}

# Get Service Account's JSON
resource "google_service_account_key" "sa_cortex_key" {
  service_account_id = "${google_service_account.sa_cortex.name}"
}

resource "google_project_iam_member" "sa_cortex" {
  project = "${var.bigtable_project}"
  role    = "roles/bigtable.admin"
  member  = "serviceAccount:${google_service_account.sa_cortex.email}"
}

# Create secret with above generated JSON content as value
resource "kubernetes_secret" "sa_cortex_secret" {
  metadata {
    name      = "sa-cortex"
    namespace = "${var.namespace}"
  }

  data {
    credentials.json = "${base64decode(google_service_account_key.sa_cortex_key.private_key)}"
  }
}
