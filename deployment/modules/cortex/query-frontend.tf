# Deployment
resource "kubernetes_deployment" "query-frontend" {
  metadata {
    name      = "cortex-query-frontend"
    namespace = "${var.namespace}"

    labels {
      app       = "cortex"
      component = "query-frontend"
    }
  }

  spec {
    replicas = "${var.query_frontend_replicas}"

    selector {
      match_labels {
        app       = "cortex"
        component = "query-frontend"
      }
    }

    template {
      metadata {
        labels {
          app       = "cortex"
          component = "query-frontend"
        }

        annotations {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "${var.query_frontend_http_port}"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
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
                    values   = ["cortex"]
                  }

                  match_expressions {
                    key      = "component"
                    operator = "In"
                    values   = ["query-frontend"]
                  }
                }

                topology_key = "failure-domain.beta.kubernetes.io/zone"
              }
            }

            # Must be spread across different nodes
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_expressions {
                  key      = "app"
                  operator = "In"
                  values   = ["cortex"]
                }

                match_expressions {
                  key      = "component"
                  operator = "In"
                  values   = ["query-frontend"]
                }
              }

              topology_key = "kubernetes.io/hostname"
            }
          }
        }

        container {
          image             = "${var.cortex_docker_image}"
          image_pull_policy = "IfNotPresent"
          name              = "query-frontend"

          args = [
            "-target=query-frontend",
            "-server.http-listen-port=${var.query_frontend_http_port}",
            "-server.grpc-listen-port=${var.grpc_port}",
            "-server.grpc-max-recv-msg-size-bytes=104857600",
            "-querier.split-queries-by-day=true",
            "-querier.align-querier-with-step=true",
            "-frontend.max-cache-freshness=10m",
            "-frontend.memcached.hostname=${kubernetes_service.memcached.metadata.0.name}.${var.namespace}",
            "-frontend.memcached.service=memcached-client",
            "-frontend.memcached.timeout=200ms",
            "-querier.align-querier-with-step=true",
            "-querier.cache-results=true",
            "-querier.compress-http-responses=true",
            "-querier.split-queries-by-day=true",
            "-server.http-write-timeout=1m",
            "-store.max-query-length=6000h",
          ]

          port {
            name           = "http"
            container_port = "${var.query_frontend_http_port}"
          }

          port {
            name           = "grpc"
            container_port = "${var.grpc_port}"
          }

          # Jaeger setup
          env = {
            name = "JAEGER_AGENT_HOST"

            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }

          env = {
            name  = "JAEGER_AGENT_PORT"
            value = "${var.jaeger_agent_port}"
          }

          env = {
            name  = "JAEGER_SAMPLER_TYPE"
            value = "ratelimiting"
          }

          env = {
            name  = "JAEGER_SAMPLER_PARAM"
            value = "7"
          }
        }
      }
    }
  }
}

# Service
resource "kubernetes_service" "query-frontend" {
  metadata {
    name      = "cortex-query-frontend"
    namespace = "${var.namespace}"
  }

  spec {
    selector {
      app       = "${kubernetes_deployment.query-frontend.spec.0.template.0.metadata.0.labels.app}"
      component = "${kubernetes_deployment.query-frontend.spec.0.template.0.metadata.0.labels.component}"
    }

    port {
      name = "http"
      port = "${var.query_frontend_http_port}"
    }

    port {
      name = "grpc"
      port = "${var.grpc_port}"
    }
  }
}

# Service
resource "kubernetes_service" "query-frontend-headless" {
  metadata {
    name      = "cortex-query-frontend-headless"
    namespace = "${var.namespace}"
  }

  spec {
    selector {
      app       = "${kubernetes_deployment.query-frontend.spec.0.template.0.metadata.0.labels.app}"
      component = "${kubernetes_deployment.query-frontend.spec.0.template.0.metadata.0.labels.component}"
    }

    cluster_ip = "None"
    
    port {
      name = "http"
      port = "${var.query_frontend_http_port}"
    }

    port {
      name = "grpc"
      port = "${var.grpc_port}"
    }
  }
}
