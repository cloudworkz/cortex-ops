# Deployment
resource "kubernetes_deployment" "distributor" {
  metadata {
    name      = "cortex-distributor"
    namespace = "${var.namespace}"

    labels {
      app       = "cortex"
      component = "distributor"
    }
  }

  spec {
    replicas = "${var.distributor_replicas}"

    selector {
      match_labels {
        app       = "cortex"
        component = "distributor"
      }
    }

    template {
      metadata {
        labels {
          app       = "cortex"
          component = "distributor"
        }

        annotations {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "${var.distributor_http_port}"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        volume {
          name = "${kubernetes_config_map.tenant_limit_config.metadata.0.name}"

          config_map = {
            name = "${kubernetes_config_map.tenant_limit_config.metadata.0.name}"
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
                    values   = ["cortex"]
                  }

                  match_expressions {
                    key      = "component"
                    operator = "In"
                    values   = ["distributor"]
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
                    values   = ["distributor"]
                  }
                }

                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }

        container {
          image             = "${var.cortex_docker_image}"
          image_pull_policy = "IfNotPresent"
          name              = "distributor"

          args = [
            "-target=distributor",
            "-server.http-listen-port=${var.distributor_http_port}",
            "-consul.hostname=${var.consul_hostname}:${var.consul_port}",
            "-distributor.health-check-ingesters=true",
            "-distributor.ingestion-burst-size=200000",
            "-distributor.ingestion-rate-limit=100000",
            "-distributor.remote-timeout=20s",
            "-distributor.replication-factor=3",
            "-distributor.shard-by-all-labels=true",
            "-ring.heartbeat-timeout=5m",
            "-validation.reject-old-samples=true",
            "-validation.reject-old-samples.max-age=12h",
            "-limits.per-user-override-config=/etc/cortex/validation/config.yaml",
          ]

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
            container_port = "${var.distributor_http_port}"
          }

          volume_mount {
            name       = "${kubernetes_config_map.tenant_limit_config.metadata.0.name}"
            mount_path = "/etc/cortex/validation"
          }
        }
      }
    }
  }
}

# Service
resource "kubernetes_service" "distributor" {
  metadata {
    name      = "cortex-distributor"
    namespace = "${var.namespace}"
  }

  spec {
    selector {
      app       = "${kubernetes_deployment.distributor.spec.0.template.0.metadata.0.labels.app}"
      component = "${kubernetes_deployment.distributor.spec.0.template.0.metadata.0.labels.component}"
    }

    port {
      name = "distributor"
      port = "${var.distributor_http_port}"
    }
  }
}
