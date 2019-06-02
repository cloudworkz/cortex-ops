# KMS is used to decrypt secrets upon terraform apply
data "google_kms_key_ring" "kubernetes" {
  project  = "projectname"
  name     = "kubernetes"
  location = "europe-west1"
}

data "google_kms_crypto_key" "kubernetes" {
  name     = "kubernetes"
  key_ring = "${data.google_kms_key_ring.kubernetes.id}"
}
