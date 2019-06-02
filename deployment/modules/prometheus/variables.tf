# Prometheus Config Map
variable "remote_write_url" {
  type = "string"

  # http://cortex-gateway.monitoring:80/api/prom/push
}

variable "namespace" {
  type = "string"
}

variable "bearer_token" {
  type = "string"
}

variable "nodepool" {
  type = "string"
}
