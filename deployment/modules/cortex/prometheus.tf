# Deployment
resource "kubernetes_deployment" "prometheus" {
  metadata {
    name      = "cortex-prometheus"
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
        service_account_name = "sa-cortex-prometheus"

        # Config Map Volume
        volume {
          name = "${kubernetes_config_map.prometheus.metadata.0.name}"

          config_map = {
            name = "${kubernetes_config_map.prometheus.metadata.0.name}"
          }
        }

        # Persistent Storage Volume
        volume {
          name = "storage-volume"

          empty_dir = {}
        }

        init_container {
          image             = "busybox:latest"
          image_pull_policy = "IfNotPresent"
          command           = ["chown", "-R", "65534:65534", "/data"]
          name              = "busybox"

          volume_mount {
            name       = "storage-volume"
            mount_path = "/data"
          }
        }

        container {
          image             = "prom/prometheus:v2.9.2"
          image_pull_policy = "IfNotPresent"
          name              = "prometheus"

          args = [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.path=/data",
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
            name       = "storage-volume"
            mount_path = "/data"
          }

          port {
            name           = "prometheus"
            container_port = "9090"
          }

          resources {
            limits {
              cpu    = "1"
              memory = "2Gi"
            }

            requests {
              cpu    = "0.1"
              memory = "100Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/-/ready"
              port = "9090"
            }

            initial_delay_seconds = 10
          }

          liveness_probe {
            http_get {
              path = "/-/healthy"
              port = "9090"
            }

            initial_delay_seconds = 10
          }
        }
      }
    }
  }
}

# Prometheus Config Map
resource "kubernetes_config_map" "prometheus" {
  metadata {
    name      = "prometheus-config"
    namespace = "${var.namespace}"
  }

  data {
    prometheus.yml = "${file("./modules/cortex/prometheus-config.yml")}"
  }
}

# Service
resource "kubernetes_service" "prometheus" {
  metadata {
    name      = "cortex-prometheus"
    namespace = "${var.namespace}"
  }

  spec {
    selector {
      app       = "${kubernetes_deployment.prometheus.spec.0.template.0.metadata.0.labels.app}"
      component = "${kubernetes_deployment.prometheus.spec.0.template.0.metadata.0.labels.component}"
    }

    port {
      name = "cortex-prometheus"
      port = "9090"
    }
  }
}

# Cluster Role
resource "kubernetes_cluster_role" "prometheus" {
  metadata {
    name = "sa-cortex-prometheus"
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
    name = "sa-cortex-prometheus"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "sa-cortex-prometheus"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "sa-cortex-prometheus"
    namespace = "${var.namespace}"
  }
}

# Service Account
resource "kubernetes_service_account" "prometheus" {
  metadata {
    name      = "sa-cortex-prometheus"
    namespace = "${var.namespace}"
  }

  automount_service_account_token = "true"
}
