resource "kubernetes_daemonset" "agent" {
  metadata {
    name      = "jaeger-agent"
    namespace = "${var.namespace}"

    labels {
      app       = "jaeger"
      component = "agent"
    }
  }

  spec {
    selector {
      match_labels {
        app       = "jaeger"
        component = "agent"
      }
    }

    template {
      metadata {
        labels {
          app       = "jaeger"
          component = "agent"
        }

        annotations {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "14271"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        dns_policy = "ClusterFirst"

        container {
          image             = "jaegertracing/jaeger-agent:1.12.0"
          image_pull_policy = "IfNotPresent"
          name              = "agent"

          env = {
            name  = "COLLECTOR_HOST_PORT"
            value = "${kubernetes_service.collector.metadata.0.name}.${var.namespace}:14267"
          }

          resources {
            limits {
              cpu    = "500m"
              memory = "200Mi"
            }

            requests {
              cpu    = "20m"
              memory = "50Mi"
            }
          }

          port {
            name           = "zipkin"
            protocol       = "UDP"
            container_port = "5775"
          }

          port {
            name           = "compact"
            protocol       = "UDP"
            container_port = "6831"
          }

          port {
            name           = "binary"
            protocol       = "UDP"
            container_port = "6832"
          }

          port {
            name           = "sampling"
            protocol       = "TCP"
            container_port = "5778"
          }

          port {
            name           = "health"
            protocol       = "TCP"
            container_port = "14271"
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

resource "kubernetes_service" "agent" {
  metadata {
    name      = "jaeger-agent"
    namespace = "${var.namespace}"
  }

  spec {
    selector {
      app       = "${kubernetes_daemonset.agent.spec.0.template.0.metadata.0.labels.app}"
      component = "${kubernetes_daemonset.agent.spec.0.template.0.metadata.0.labels.component}"
    }

    port {
      name     = "zipkin"
      protocol = "UDP"
      port     = "5775"
    }

    port {
      name     = "compact"
      protocol = "UDP"
      port     = "6831"
    }

    port {
      name     = "binary"
      protocol = "UDP"
      port     = "6832"
    }

    port {
      name     = "sampling"
      protocol = "TCP"
      port     = "5778"
    }

    port {
      name     = "health"
      protocol = "TCP"
      port     = "14271"
    }
  }
}
