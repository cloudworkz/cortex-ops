# General variables
variable "namespace" {
  type = "string"
}

variable "nodepool" {
  type = "string"
}

variable "elasticsearch_url" {
  type = "string"
}

# Collector
variable "collector_replicas" {
  default = "3"
}

# Query
variable "query_replicas" {
  default = "3"
}
