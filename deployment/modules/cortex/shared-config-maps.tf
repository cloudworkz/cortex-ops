# Schema Config
resource "kubernetes_config_map" "schema_config" {
  metadata {
    name      = "cortex-schema-config"
    namespace = "${var.namespace}"
  }

  data {
    config.yaml = "${file("./modules/cortex/schema-config.yaml")}"
  }
}

# Per Tenant Validation Limits
resource "kubernetes_config_map" "tenant_limit_config" {
  metadata {
    name      = "tenant-limit-config"
    namespace = "${var.namespace}"
  }

  data {
    config.yaml = "${file("./modules/cortex/tenant-limit-config.yaml")}"
  }
}
