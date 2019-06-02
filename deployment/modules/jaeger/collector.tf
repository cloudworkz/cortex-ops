# Deployment
resource "kubernetes_deployment" "collector" {
  metadata {
    name      = "jaeger-collector"
    namespace = "${var.namespace}"

    labels {
      app       = "jaeger"
      component = "collector"
    }
  }

  spec {
    replicas = "${var.collector_replicas}"

    strategy {
      type = "Recreate"
    }

    selector {
      match_labels {
        app       = "jaeger"
        component = "collector"
      }
    }

    template {
      metadata {
        labels {
          app       = "jaeger"
          component = "collector"
        }

        annotations {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "14269"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        dns_policy = "ClusterFirst"

        volume {
          name = "elasticsearch-certs"

          secret = {
            secret_name = "tracing-ca"
          }
        }

        node_selector {
          "cloud.google.com/gke-nodepool" = "${var.nodepool}"
        }

        affinity {
          pod_anti_affinity {
            # If possible spread across AV zones
            preferred_during_scheduling_ignored_during_execution {
              weight = 100

              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "app"
                    operator = "In"
                    values   = ["jaeger"]
                  }

                  match_expressions {
                    key      = "component"
                    operator = "In"
                    values   = ["collector"]
                  }
                }

                topology_key = "failure-domain.beta.kubernetes.io/zone"
              }
            }

            # If possible spread across nodes
            preferred_during_scheduling_ignored_during_execution {
              weight = 20

              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "app"
                    operator = "In"
                    values   = ["jaeger"]
                  }

                  match_expressions {
                    key      = "component"
                    operator = "In"
                    values   = ["collector"]
                  }
                }

                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }

        container {
          image             = "jaegertracing/jaeger-collector:1.12.0"
          image_pull_policy = "IfNotPresent"
          name              = "collector"

          port {
            name           = "thrift-spans"
            protocol       = "TCP"
            container_port = "14267"
          }

          port {
            name           = "proto-spans"
            protocol       = "TCP"
            container_port = "14250"
          }

          port {
            name           = "binary-spans"
            protocol       = "TCP"
            container_port = "14268"
          }

          port {
            name           = "zipkin-spans"
            protocol       = "TCP"
            container_port = "9411"
          }

          port {
            name           = "health"
            protocol       = "TCP"
            container_port = "14269"
          }

          resources {
            limits {
              cpu    = "2"
              memory = "1Gi"
            }

            requests {
              cpu    = "100m"
              memory = "300Mi"
            }
          }

          env = {
            name  = "SPAN_STORAGE_TYPE"
            value = "elasticsearch"
          }

          env = {
            name  = "ES_SERVER_URLS"
            value = "${var.elasticsearch_url}"
          }

          env = {
            name  = "ES_TLS_CA"
            value = "/etc/jaeger/elasticsearch-certs/ca.pem"
          }

          env = {
            name  = "COLLECTOR_PORT"
            value = "14267"
          }

          env = {
            name  = "COLLECTOR_HTTP_PORT"
            value = "14268"
          }

          env = {
            name  = "COLLECTOR_ZIPKIN_HTTP_PORT"
            value = "9411"
          }

          volume_mount {
            name       = "elasticsearch-certs"
            mount_path = "/etc/jaeger/elasticsearch-certs"
          }

          readiness_probe {
            http_get {
              port = "health"
              path = "/ready"
            }

            initial_delay_seconds = 10
          }

          liveness_probe {
            http_get {
              port = "health"
              path = "/health"
            }

            initial_delay_seconds = 10
          }
        }
      }
    }
  }
}

# Service
resource "kubernetes_service" "collector" {
  metadata {
    name      = "jaeger-collector"
    namespace = "${var.namespace}"
  }

  spec {
    selector {
      app       = "${kubernetes_deployment.collector.spec.0.template.0.metadata.0.labels.app}"
      component = "${kubernetes_deployment.collector.spec.0.template.0.metadata.0.labels.component}"
    }

    port {
      name     = "thrift-spans"
      protocol = "TCP"
      port     = "14267"
    }

    port {
      name     = "proto-spans"
      protocol = "TCP"
      port     = "14250"
    }

    port {
      name     = "binary-spans"
      protocol = "TCP"
      port     = "14268"
    }

    port {
      name     = "zipkin-spans"
      protocol = "TCP"
      port     = "9411"
    }

    port {
      name     = "health"
      protocol = "TCP"
      port     = "14269"
    }
  }
}
