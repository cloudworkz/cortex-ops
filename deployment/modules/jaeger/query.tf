# Deployment
resource "kubernetes_deployment" "query" {
  metadata {
    name      = "jaeger-query"
    namespace = "${var.namespace}"

    labels {
      app       = "jaeger"
      component = "query"
    }
  }

  spec {
    replicas = "${var.query_replicas}"

    strategy {
      type = "Recreate"
    }

    selector {
      match_labels {
        app       = "jaeger"
        component = "query"
      }
    }

    template {
      metadata {
        labels {
          app       = "jaeger"
          component = "query"
        }

        annotations {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "16687"
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
                    values   = ["query"]
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
                    values   = ["query"]
                  }
                }

                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }

        container {
          image             = "jaegertracing/jaeger-query:1.12.0"
          image_pull_policy = "IfNotPresent"
          name              = "query"

          port {
            name           = "ui"
            protocol       = "TCP"
            container_port = "16686"
          }

          port {
            name           = "health"
            protocol       = "TCP"
            container_port = "16687"
          }

          env = {
            name  = "QUERY_BASE_PATH"
            value = "/"
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

          volume_mount {
            name       = "elasticsearch-certs"
            mount_path = "/etc/jaeger/elasticsearch-certs"
          }

          resources {
            limits {
              cpu    = "1"
              memory = "1Gi"
            }

            requests {
              cpu    = "0.1"
              memory = "500Mi"
            }
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
resource "kubernetes_service" "query" {
  metadata {
    name      = "jaeger-query"
    namespace = "${var.namespace}"
  }

  spec {
    selector {
      app       = "${kubernetes_deployment.query.spec.0.template.0.metadata.0.labels.app}"
      component = "${kubernetes_deployment.query.spec.0.template.0.metadata.0.labels.component}"
    }

    port {
      name        = "ui"
      protocol    = "TCP"
      port        = "16686"
      target_port = "16686"
    }

    port {
      name        = "health"
      protocol    = "TCP"
      port        = "16687"
      target_port = "16687"
    }
  }
}
