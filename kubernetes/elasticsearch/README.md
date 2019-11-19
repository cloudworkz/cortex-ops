# Elasticsearch Cluster

We are using the official Elasticsearch Operator from Elastic: https://github.com/elastic/cloud-on-k8s

1. Apply the operator yaml
2. Apply the storage class
3. Adopt the operator yaml to your needs (zones, nodepool, etc)

We use this Elasticsearch cluster as backend for jaeger and also use it for logging (ELK Stack). It has a separate set of master pods which run in our default nodepool, while the data nodes run in a separate nodepool (actually a preemptible one in our case).
