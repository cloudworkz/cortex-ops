# Deployment
resource "kubernetes_deployment" "gateway" {
  metadata {
    name      = "cortex-gateway"
    namespace = "${var.namespace}"

    labels {
      app       = "cortex"
      component = "gateway"
    }
  }

  spec {
    replicas = "${var.gateway_replicas}"

    selector {
      match_labels {
        app       = "cortex"
        component = "gateway"
      }
    }

    template {
      metadata {
        labels {
          app       = "cortex"
          component = "gateway"
        }

        annotations {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "${var.ingester_http_port}"
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
                    values   = ["gateway"]
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
                    values   = ["cortex"]
                  }

                  match_expressions {
                    key      = "component"
                    operator = "In"
                    values   = ["gateway"]
                  }
                }

                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }

        container {
          image             = "quay.io/weeco/cortex-gateway@sha256:a48273b403815ff407d1c5ea765cd205584c660fac8234408b32af3b4f12d0cd"
          image_pull_policy = "IfNotPresent"
          name              = "gateway"

          args = [
            "-server.http-listen-port=${var.gateway_http_port}",
            "-gateway.distributor.address=http://${kubernetes_service.distributor.metadata.0.name}.${var.namespace}",
            "-gateway.query-frontend.address=http://${kubernetes_service.query-frontend.metadata.0.name}.${var.namespace}",
            "-gateway.auth.jwt-secret=$(JWT_SECRET)",
          ]

          env = {
            name = "JWT_SECRET"

            value_from {
              secret_key_ref {
                name = "${kubernetes_secret.jwt_secret.metadata.0.name}"
                key  = "jwt_secret"
              }
            }
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

          port {
            name           = "cortex-gateway"
            container_port = "${var.gateway_http_port}"
          }
        }
      }
    }
  }
}

# Service
resource "kubernetes_service" "gateway" {
  metadata {
    name      = "cortex-gateway"
    namespace = "${var.namespace}"
  }

  spec {
    selector {
      app       = "${kubernetes_deployment.gateway.spec.0.template.0.metadata.0.labels.app}"
      component = "${kubernetes_deployment.gateway.spec.0.template.0.metadata.0.labels.component}"
    }

    port {
      name = "cortex-gateway"
      port = "${var.gateway_http_port}"
    }
  }
}

# JWT secret
resource "kubernetes_secret" "jwt_secret" {
  metadata {
    name      = "cortex-jwt-secret"
    namespace = "${var.namespace}"
  }

  data {
    jwt_secret = "${var.gateway_jwt_secret}"
  }
}
