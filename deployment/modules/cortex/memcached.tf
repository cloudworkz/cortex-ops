# TODO: Pod disruption budget, ref: https://github.com/terraform-providers/terraform-provider-kubernetes/issues/320

# Statefulset
resource "kubernetes_stateful_set" "memcached" {
  metadata {
    name      = "memcached"
    namespace = "${var.namespace}"

    labels {
      app = "memcached"
    }

    annotations {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "9106"
      "prometheus.io/path"   = "/metrics"
    }
  }

  spec {
    service_name = "memcached"
    replicas     = "${var.memcached_replicas}"

    selector {
      match_labels {
        app = "memcached"
      }
    }

    template {
      metadata {
        labels {
          app = "memcached"
        }
      }

      spec {
        node_selector {
          "cloud.google.com/gke-nodepool" = "${var.nodepool}"
        }

        # Memcached container
        container {
          name              = "memcached"
          image             = "memcached:1.5.12-alpine"
          image_pull_policy = "IfNotPresent"

          command = [
            "memcached",
            "-m 64",     # max item memory
            "-o",
            "modern",
            "-v",
          ]

          port {
            name           = "memcache"
            container_port = 11211
          }

          resources {
            limits {
              cpu    = "1"
              memory = "1Gi"
            }

            requests {
              cpu    = "50m"
              memory = "1Gi"
            }
          }

          liveness_probe {
            tcp_socket {
              port = "memcache"
            }

            initial_delay_seconds = 30
            timeout_seconds       = 5
          }

          readiness_probe {
            tcp_socket {
              port = "memcache"
            }

            initial_delay_seconds = 5
          }
        }

        # Prometheus metrics exporter
        container {
          name              = "exporter"
          image             = "quay.io/prometheus/memcached-exporter:v0.5.0"
          image_pull_policy = "IfNotPresent"

          port {
            name           = "exporter"
            container_port = 9106
          }

          resources {
            limits {
              cpu    = "300m"
              memory = "300Mi"
            }

            requests {
              cpu    = "50m"
              memory = "64Mi"
            }
          }
        }
      }
    }
  }
}

# Service
resource "kubernetes_service" "memcached" {
  metadata {
    name      = "memcached"
    namespace = "${var.namespace}"
  }

  spec {
    selector {
      app = "${kubernetes_stateful_set.memcached.spec.0.template.0.metadata.0.labels.app}"
    }

    # The memcache client uses DNS to get a list of memcached servers and then
    # uses a consistent hash of the key to determine which server to pick.
    cluster_ip = "None"

    port {
      name = "memcached-client"
      port = "${kubernetes_stateful_set.memcached.spec.0.template.0.spec.0.container.0.port.0.container_port}"
    }

    port {
      name = "exporter"
      port = "${kubernetes_stateful_set.memcached.spec.0.template.0.spec.0.container.1.port.0.container_port}"
    }
  }
}
