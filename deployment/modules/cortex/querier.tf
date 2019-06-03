# Deployment
resource "kubernetes_deployment" "querier" {
  metadata {
    name      = "cortex-querier"
    namespace = "${var.namespace}"

    labels {
      app       = "cortex"
      component = "querier"
    }
  }

  spec {
    replicas = "${var.querier_replicas}"

    selector {
      match_labels {
        app       = "cortex"
        component = "querier"
      }
    }

    template {
      metadata {
        labels {
          app       = "cortex"
          component = "querier"
        }

        annotations {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "${var.querier_http_port}"
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
                    values   = ["querier"]
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
                  values   = ["querier"]
                }
              }

              topology_key = "kubernetes.io/hostname"
            }
          }
        }

        container {
          image             = "${var.cortex_docker_image}"
          image_pull_policy = "IfNotPresent"
          name              = "querier"

          args = [
            "-target=querier",
            "-server.http-listen-port=${var.querier_http_port}",
            "-server.http-write-timeout=1m",
            "-consul.hostname=${var.consul_hostname}:${var.consul_port}",
            "-querier.frontend-address=${kubernetes_service.query-frontend-headless.metadata.0.name}.${kubernetes_service.query-frontend-headless.metadata.0.namespace}:${var.grpc_port}",
            "-querier.batch-iterators=true",
            "-querier.ingester-streaming=true",
            "-querier.frontend-client.grpc-max-send-msg-size=104857600",
            "-querier.max-concurrent=4",
            "-querier.max-samples=100000000",
            "-querier.query-ingesters-within=12h",
            "-querier.worker-parallelism=2",
            "-ring.heartbeat-timeout=5m",
            "-distributor.health-check-ingesters=true",
            "-distributor.replication-factor=3",
            "-distributor.shard-by-all-labels=true",
            "-bigtable.instance=${var.bigtable_instance}",
            "-bigtable.project=${var.bigtable_project}",
            "-store.cache-lookups-older-than=36h",
            "-store.cardinality-limit=2000000",
            "-store.index-cache-read.cache.enable-fifocache=true",
            "-store.index-cache-read.fifocache.size=102400",
            "-store.index-cache-read.memcached.hostname=${kubernetes_service.memcached.metadata.0.name}.${kubernetes_service.memcached.metadata.0.namespace}",
            "-store.index-cache-read.memcached.service=memcached-client",
            "-store.index-cache-validity=14m",
            "-store.max-query-length=744h",
            "-store.min-chunk-age=15m",
            "-memcached.hostname=${kubernetes_service.memcached.metadata.0.name}.${kubernetes_service.memcached.metadata.0.namespace}",
            "-memcached.service=memcached-client",
            "-memcached.batchsize=1024",
            "-memcached.timeout=3s",
            "-distributor.replication-factor=3",
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
            container_port = "${var.querier_http_port}"
          }

          resources {
            limits {
              cpu    = "1"
              memory = "2Gi"
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
resource "kubernetes_service" "querier" {
  metadata {
    name      = "cortex-querier"
    namespace = "${var.namespace}"
  }

  spec {
    selector {
      app       = "${kubernetes_deployment.querier.spec.0.template.0.metadata.0.labels.app}"
      component = "${kubernetes_deployment.querier.spec.0.template.0.metadata.0.labels.component}"
    }

    port {
      name = "querier"
      port = "${var.querier_http_port}"
    }
  }
}
