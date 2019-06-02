# Deploy Cortex
module "cortex" {
  source             = "../modules/cortex"
  namespace          = "${kubernetes_namespace.monitoring.metadata.0.name}"
  nodepool           = "default"
  consul_hostname    = "consul-server.hashicorp.svc.cluster.local"
  consul_port        = 8500
  bigtable_project   = "projectname"
  bigtable_instance  = "cortex"
  gateway_jwt_secret = "${data.google_kms_secret.gateway_jwt_secret.plaintext}"
}

# Prometheus which sends samples via remote write API to cortex
module "prometheus" {
  source           = "../modules/prometheus"
  nodepool         = "default"
  namespace        = "${kubernetes_namespace.monitoring.metadata.0.name}"
  bearer_token     = "${data.google_kms_secret.prometheus_bigdata_bearer_token.plaintext}"
  remote_write_url = "http://cortex-gateway.monitoring:80/api/prom/push"
}

# Deploy Jaeger for tracing
module "jaeger" {
  source            = "../modules/jaeger"
  namespace         = "${kubernetes_namespace.monitoring.metadata.0.name}"
  nodepool          = "default"
  elasticsearch_url = "https://tracing-es.monitoring.svc.cluster.local:9200"
}

data "google_container_cluster" "cluster" {
  name    = "bigdata"
  zone    = "europe-west1-c"
  project = "projectname"
}

data "google_client_config" "default" {}

provider "kubernetes" {
  load_config_file       = false
  host                   = "https://${data.google_container_cluster.cluster.endpoint}"
  token                  = "${data.google_client_config.default.access_token}"
  cluster_ca_certificate = "${base64decode(data.google_container_cluster.cluster.master_auth.0.cluster_ca_certificate)}"
}
