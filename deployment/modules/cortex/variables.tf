# General variables
variable "namespace" {
  type = "string"
}

variable "nodepool" {
  type = "string"
}

variable "consul_hostname" {
  type = "string"
}

variable "consul_port" {}

variable "grpc_port" {
  default = 9095
}

variable "bigtable_project" {
  type = "string"
}

variable "bigtable_instance" {
  type = "string"
}

variable "cortex_docker_image" {
  default = "quay.io/cortexproject/cortex:master-5534e39a"
}

variable "jaeger_agent_port" {
  default = 6831
}

# Distributor
variable "distributor_replicas" {
  default = 4
}

variable "distributor_http_port" {
  default = 80
}

# Ingester
variable "ingester_replicas" {
  default = 6
}

variable "ingester_http_port" {
  default = 80
}

# Querier
variable "querier_replicas" {
  default = 4
}

variable "querier_http_port" {
  default = 80
}

# Query Frontend
variable "query_frontend_replicas" {
  default = 2
}

variable "query_frontend_http_port" {
  default = 80
}

# Table Manager
variable "table_manager_replicas" {
  default = 1
}

variable "table_manager_http_port" {
  default = 80
}

# Memcached
variable "memcached_replicas" {
  default = 3
}

# Gateway
variable "gateway_replicas" {
  default = 2
}

variable "gateway_http_port" {
  default = 80
}

variable "gateway_jwt_secret" {
  type = "string"
}
