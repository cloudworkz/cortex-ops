# Deployment
resource "kubernetes_deployment" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = "${var.namespace}"

    labels {
      app       = "cortex"
      component = "prometheus"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels {
        app       = "cortex"
        component = "prometheus"
      }
    }

    template {
      metadata {
        labels {
          app       = "cortex"
          component = "prometheus"
        }

        annotations {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "9090"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        service_account_name = "sa-remote-prometheus"

        volume {
          name = "${kubernetes_config_map.prometheus.metadata.0.name}"

          config_map = {
            name = "${kubernetes_config_map.prometheus.metadata.0.name}"
          }
        }

        volume {
          name = "bearer-token"

          secret = {
            secret_name = "${kubernetes_secret.bearer_token.metadata.0.name}"
          }
        }

        node_selector {
          "cloud.google.com/gke-nodepool" = "${var.nodepool}"
        }

        container {
          image             = "prom/prometheus:v2.10.0"
          image_pull_policy = "IfNotPresent"
          name              = "prometheus"

          args = [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.no-lockfile",
            "--storage.tsdb.min-block-duration=2h",
            "--storage.tsdb.max-block-duration=2h",
            "--storage.tsdb.retention.time=1d",
            "--web.enable-lifecycle",
            "--web.console.libraries=/etc/prometheus/console_libraries",
            "--web.console.templates=/etc/prometheus/consoles",
          ]

          volume_mount {
            name       = "${kubernetes_config_map.prometheus.metadata.0.name}"
            mount_path = "/etc/prometheus"
          }

          volume_mount {
            name       = "bearer-token"
            mount_path = "/etc/secrets"
          }

          port {
            container_port = "9090"
          }

          resources {
            limits {
              cpu    = "2"
              memory = "6Gi"
            }

            requests {
              cpu    = "1"
              memory = "4Gi"
            }
          }
        }
      }
    }
  }
}

# Prometheus Config Map
data "template_file" "prometheus_config" {
  template = "${file("${path.module}/prometheus-config.yaml")}"

  vars = {
    remote_write_url = "${var.remote_write_url}"
  }
}

resource "kubernetes_config_map" "prometheus" {
  metadata {
    name      = "prometheus-remote-config"
    namespace = "${var.namespace}"
  }

  data {
    prometheus.yml = "${data.template_file.prometheus_config.rendered}"
  }
}

# Bearer Token Secret
resource "kubernetes_secret" "bearer_token" {
  metadata {
    name      = "prometheus-remote-bearer-token"
    namespace = "${var.namespace}"
  }

  data {
    bearer_token.txt = "${var.bearer_token}"
  }
}

# Service
resource "kubernetes_service" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = "${var.namespace}"
  }

  spec {
    selector {
      app       = "${kubernetes_deployment.prometheus.spec.0.template.0.metadata.0.labels.app}"
      component = "${kubernetes_deployment.prometheus.spec.0.template.0.metadata.0.labels.component}"
    }

    port {
      name = "prometheus"
      port = "9090"
    }
  }
}

# Cluster Role
resource "kubernetes_cluster_role" "prometheus" {
  metadata {
    name = "sa-remote-prometheus"
  }

  rule {
    api_groups = [""]

    resources = [
      "nodes",
      "nodes/proxy",
      "services",
      "endpoints",
      "pods",
      "ingresses",
      "configmaps",
    ]

    verbs = [
      "get",
      "list",
      "watch",
    ]
  }

  rule {
    api_groups = ["extensions"]

    resources = [
      "ingresses/status",
      "ingresses",
    ]

    verbs = [
      "get",
      "list",
      "watch",
    ]
  }

  rule {
    non_resource_urls = ["/metrics"]
    verbs             = ["get"]
  }
}

# Cluster Role Binding
resource "kubernetes_cluster_role_binding" "prometheus" {
  metadata {
    name = "sa-remote-prometheus"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "sa-remote-prometheus"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "sa-remote-prometheus"
    namespace = "${var.namespace}"
  }
}

# Service Account
resource "kubernetes_service_account" "prometheus" {
  metadata {
    name      = "sa-remote-prometheus"
    namespace = "${var.namespace}"
  }

  automount_service_account_token = "true"
}
