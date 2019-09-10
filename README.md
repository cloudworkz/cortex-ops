# Cortex Ops

This repository has been created to build a community around operating [Cortex](https://github.com/cortexproject/cortex). Therefore we encourage you to share your learnings, improvement proposals, challenges and failures so that we can learn from each other and ultimately come up with a decent guide about operating Cortex.

**In this repository we seek to provide:**

- A production ready setup (created for GKE + BigTable) which should suit most companies' needs in terms of scale and performance
- Operational knowledge (FAQs, clarifying the microservice architecture)
- Premade monitoring solutions (Grafana dashboards)

Most of the granted information shall serve as inspiration for your own deployment. Due to the complexity and the large variety of configurations it is very likely that this setup does not suit all your needs.

**Note**: This setup uses Google's BigTable without an additional Bucket storage for storing all chunks and indexes.

## Kubernetes deployment

All deployment files and the corresponding documentation can be found in `./kubernetes`. It has been tested on GKE and built for the usage of BigTable as underlying time series database.

**As of now the deployment manifests cover the following components:**

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
- Other underlying Timeseries Databases for Cortex (such as Cassandra or DynamoDB)
- Grafana deployment with provisioned datasources querying Cortex

We can recommend [Elastic's Kubernetes Operator](https://github.com/elastic/cloud-on-k8s) for creating Elasticsearch clusters.

## Grafana Monitoring

To be created..

## Ops Guides

To be created..

## Tenant Authentication with Cortex Gatway

In order to store and query tenants' metrics separately from each other Cortex requires a User id which must be set in the headers (`X-Scope-OrgID`). Since you can not provide custom headers in the Prometheus Remote Write API, nor in the Grafana UI for a datasource, you could deploy a NGINX cluster in each of your tenants which does that for you and proxies these requests to your Cortex Gateway.

Cortex completely trusts the `X-Scope-OrgID` and it is your responsibility to ensure the header value is correct. This may work fine in a trusted, self controlled environment, however in most cases you want more control than that. You may want to issue JSON web tokens for your tenants, do additional validation based on the claims, invalidate tokens etc. The Cortex Gateway helps you with that and you can easily replace it with your own implementation, as it's very rudimentary as of writing this. In the prometheus remote write API config you can specify the Bearer Token and in Grafana you must provision a new Datasource where you can specify this bearer token as well. Once https://github.com/grafana/grafana/pull/17846 is merged you can specify the Bearer token for your datasource in the Grafana UI as well. Take a look at the [Cortex Gateway Documentation](https://github.com/weeco/cortex-gateway) to learn more about our approach to solve multitenancy.
