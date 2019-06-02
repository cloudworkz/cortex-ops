# Deployment

We use Terraform's Kubernetes Provider to deploy Cortex and it's dependencies. The Kubernetes provider is rather new and lacks a couple features which may be beneficial. If possible we then provide a Kubernetes manifest to use this feature. If this is not possible (like a missing option in the deployment) we submit an issue and flag it with "terraform". Once these features / bugs are resolved we will update the terraform module accordingly.

**Currently these Terraform modules cover the deployment of:**

- Jaeger (Agent Daemonset, Collector Deployment, UI Deployemnt)
- Prometheus, which is responsible for sending metrics from tenants to your Cortex cluster using the remote write API
- Cortex, which includes:
  - Distributor
  - [Gateway](https://github.com/weeco/cortex-gateway) - Auth Gateway (not part of Cortex)
  - Ingester
  - Memcached
  - Prometheus (exclusively used to monitor all Cortex components - just in case Cortex is down)
  - Querier
  - Query Frontend
  - Table Manager

**Deployments which are not covered (yet):**

- Consul (required for Cortex components)
- Elasticsearch / Cassandra (required for Jaeger)
- Cortex components required for Alertmanager (ruler, configs API, postgres db)

We had good experience using [Elastic's Kubernetes Operator](https://github.com/elastic/cloud-on-k8s) for creating Elasticsearch clusters.

## Tenant Authentication with Cortex Gatway

In order sto store and query tenants' metrics separately from each other Cortex requires a User id which must be set in the headers (`X-Scope-OrgID`). Since you can not provide custom headers in the Prometheus Remote Write API, nor in the Grafana UI for a datasource, you could deploy a NGINX cluster in each of your tenants which does that for you and proxies these requests to your Cortex Gateway.

This may work fine in a trusted, self controlled environment, however in most cases however you want more contorl than that. You may want to issue JSON web tokens for your tenants, do additional validation based on the claims, invalidate tokens etc. The Cortex Gateway helps you with that and you can easily replace it with your own implementation, as it's very rudimentary as of writing this. In the prometheus remote write API config you can specify the Bearer Token and in Grafana you must provision a new Datasource where you can specify this bearer token as well. Once https://github.com/grafana/grafana/issues/12779 is merged you can specify the Bearer token for your datasource in the Grafana UI as well.
