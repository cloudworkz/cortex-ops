# Deployment
resource "kubernetes_deployment" "ingester" {
  metadata {
    name      = "cortex-ingester"
    namespace = "${var.namespace}"

    labels {
      app       = "cortex"
      component = "ingester"
    }
  }

  spec {
    replicas = "${var.ingester_replicas}"

    # Ingesters are not ready for at least 1 min
    # after creation.  This has to be in sync with
    # the ring timeout value, as this will stop a
    # stampede of new ingesters if we should loose
    # some.
    min_ready_seconds = 60

    # Having maxSurge 0 and maxUnavailable 1 means
    # the deployment will update one ingester at a time
    # as it will have to stop one (making one unavailable)
    # before it can start one (surge of zero)
    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_surge       = 0
        max_unavailable = 1
      }
    }

    selector {
      match_labels {
        app       = "cortex"
        component = "ingester"
      }
    }

    template {
      metadata {
        labels {
          app       = "cortex"
          component = "ingester"
        }

        annotations {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "${var.ingester_http_port}"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        # Give ingesters 40 minutes grace to flush chunks and exit cleanly.
        # Service is available during this time, as long as we don't stop
        # too many ingesters at once.
        termination_grace_period_seconds = 2400

        volume {
          name = "${kubernetes_config_map.schema_config.metadata.0.name}"

          config_map = {
            name = "${kubernetes_config_map.schema_config.metadata.0.name}"
          }
        }

        volume {
          name = "${kubernetes_config_map.tenant_limit_config.metadata.0.name}"

          config_map = {
            name = "${kubernetes_config_map.tenant_limit_config.metadata.0.name}"
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
                    values   = ["ingester"]
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
                  values   = ["ingester"]
                }
              }

              topology_key = "kubernetes.io/hostname"
            }
          }
        }

        container {
          image             = "${var.cortex_docker_image}"
          image_pull_policy = "IfNotPresent"
          name              = "ingester"

          args = [
            "-target=ingester",
            "-server.http-listen-port=${var.ingester_http_port}",
            "-server.grpc-max-concurrent-streams=100000",
            "-ingester.chunk-encoding=3",
            "-ingester.join-after=30s",
            "-ingester.claim-on-rollout=true",
            "-ingester.max-chunk-age=6h",
            "-ingester.max-chunk-idle=15m",
            "-ingester.max-series-per-metric=10000",
            "-ingester.max-series-per-user=250000",
            "-ingester.max-transfer-retries=60",
            "-ingester.normalise-tokens=true",
            "-ingester.num-tokens=512",
            "-ingester.retain-period=15m",
            "-validation.reject-old-samples=true",
            "-consul.hostname=${var.consul_hostname}:${var.consul_port}",
            "-memcached.batchsize=1024",
            "-memcached.hostname=${kubernetes_service.memcached.metadata.0.name}.${var.namespace}",
            "-memcached.timeout=3s",
            "-memcached.service=memcached-client",
            "-bigtable.instance=${var.bigtable_instance}",
            "-bigtable.project=${var.bigtable_project}",
            "-config-yaml=/etc/cortex/schema/config.yaml",
            "-limits.per-user-override-config=/etc/cortex/validation/config.yaml",
          ]

          # Run Garbage Collector when 60% extra memory has been allocated instead of
          # default 100%. This slows the growth of the process.
          # env = {
          #   name  = "GOGC"
          #   value = 60
          # }

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
          env = {
            name  = "GOOGLE_APPLICATION_CREDENTIALS"
            value = "/var/secrets/google/credentials.json"
          }
          volume_mount {
            name       = "${kubernetes_config_map.schema_config.metadata.0.name}"
            mount_path = "/etc/cortex/schema"
          }
          volume_mount {
            name       = "${kubernetes_config_map.tenant_limit_config.metadata.0.name}"
            mount_path = "/etc/cortex/validation"
          }
          volume_mount {
            name       = "${kubernetes_secret.sa_cortex_secret.metadata.0.name}"
            mount_path = "/var/secrets/google"
          }
          port {
            container_port = "${var.ingester_http_port}"
          }
          resources {
            limits {
              cpu    = "2"
              memory = "10Gi"
            }

            requests {
              cpu    = "1"
              memory = "8Gi"
            }
          }
          readiness_probe {
            http_get {
              path = "/ready"
              port = "${var.ingester_http_port}"
            }

            initial_delay_seconds = 15
            timeout_seconds       = "${var.ingester_http_port}"
          }
        }
      }
    }
  }
}

# Service
resource "kubernetes_service" "ingester" {
  metadata {
    name      = "cortex-ingester"
    namespace = "${var.namespace}"
  }

  spec {
    selector {
      app       = "${kubernetes_deployment.ingester.spec.0.template.0.metadata.0.labels.app}"
      component = "${kubernetes_deployment.ingester.spec.0.template.0.metadata.0.labels.component}"
    }

    port {
      name = "ingester"
      port = "${var.ingester_http_port}"
    }
  }
}
