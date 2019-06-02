# Add prometheus with remote write

data "google_container_cluster" "cluster" {
  name    = "int"
  zone    = "europe-west1-c"
  project = "projectname-a"
}

data "google_client_config" "default" {}

provider "kubernetes" {
  load_config_file       = false
  host                   = "https://${data.google_container_cluster.cluster.endpoint}"
  token                  = "${data.google_client_config.default.access_token}"
  cluster_ca_certificate = "${base64decode(data.google_container_cluster.cluster.master_auth.0.cluster_ca_certificate)}"
}
