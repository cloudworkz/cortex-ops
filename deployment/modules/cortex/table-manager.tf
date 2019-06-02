# Deployment
resource "kubernetes_deployment" "table_manager" {
  metadata {
    name      = "cortex-table-manager"
    namespace = "${var.namespace}"

    labels {
      app       = "cortex"
      component = "table-manager"
    }
  }

  spec {
    replicas = "${var.table_manager_replicas}"

    selector {
      match_labels {
        app       = "cortex"
        component = "table-manager"
      }
    }

    template {
      metadata {
        labels {
          app       = "cortex"
          component = "table-manager"
        }

        annotations {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "${var.table_manager_http_port}"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        volume {
          name = "${kubernetes_config_map.schema_config.metadata.0.name}"

          config_map = {
            name = "${kubernetes_config_map.schema_config.metadata.0.name}"
          }
        }

        volume {
          name = "${kubernetes_secret.sa_cortex_secret.metadata.0.name}"

          secret = {
            secret_name = "${kubernetes_secret.sa_cortex_secret.metadata.0.name}"
          }
        }

        node_selector {
          "cloud.google.com/gke-nodepool" = "${var.nodepool}"
        }

        container {
          image             = "${var.cortex_docker_image}"
          image_pull_policy = "IfNotPresent"
          name              = "table-manager"

          args = [
            "-target=table-manager",
            "-server.http-listen-port=${var.table_manager_http_port}",
            "-bigtable.backoff-on-ratelimits=true",
            "-bigtable.grpc-client-rate-limit=5",
            "-bigtable.grpc-client-rate-limit-burst=5",
            "-bigtable.instance=${var.bigtable_instance}",
            "-bigtable.project=${var.bigtable_project}",
            "-table-manager.retention-deletes-enabled=true",
            "-table-manager.retention-period=4380h",
            "-dynamodb.chunk-table.inactive-read-throughput=0",
            "-dynamodb.chunk-table.inactive-write-throughput=0",
            "-dynamodb.chunk-table.read-throughput=0",
            "-dynamodb.chunk-table.write-throughput=0",
            "-dynamodb.use-periodic-tables=true",
            "-dynamodb.periodic-table.inactive-read-throughput=0",
            "-dynamodb.periodic-table.inactive-write-throughput=0",
            "-dynamodb.periodic-table.read-throughput=0",
            "-dynamodb.periodic-table.write-throughput=0",
            "-dynamodb.poll-interval=5m",
            "-config-yaml=/etc/cortex/schema/config.yaml",
          ]

          env = {
            name  = "GOOGLE_APPLICATION_CREDENTIALS"
            value = "/var/secrets/google/credentials.json"
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

          volume_mount {
            name       = "${kubernetes_config_map.schema_config.metadata.0.name}"
            mount_path = "/etc/cortex/schema"
          }

          volume_mount {
            name       = "${kubernetes_secret.sa_cortex_secret.metadata.0.name}"
            mount_path = "/var/secrets/google"
          }

          port {
            name           = "http"
            container_port = "${var.table_manager_http_port}"
          }

          port {
            name           = "grpc"
            container_port = "${var.grpc_port}"
          }

          resources {
            limits {
              cpu    = "0.5"
              memory = "512Mi"
            }

            requests {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}

# Service
resource "kubernetes_service" "table-manager" {
  metadata {
    name      = "cortex-table-manager"
    namespace = "${var.namespace}"
  }

  spec {
    selector {
      app       = "${kubernetes_deployment.table_manager.spec.0.template.0.metadata.0.labels.app}"
      component = "${kubernetes_deployment.table_manager.spec.0.template.0.metadata.0.labels.component}"
    }

    port {
      name = "http"
      port = "${var.table_manager_http_port}"
    }
  }
}
