# Kubernetes deployment

These Kubernetes manifests should give you an idea how to install Cortex in your environment. Please take note that you must modify some of the manifests as described below.

## Single AZ vs multiple AZ

Cortex does not yet support zone aware replication (see https://github.com/cortexproject/cortex/issues/612). For this reason you will likely not get the sort of high availabiltiy you wish for. However with a multi AZ setup you can atleast ensure that you can write metrics into your underlying time series database and that most of the metrics (except those which lost all 3 replicas in case of a AZ failure) can also be queried without any gaps.

If you decide to deploy Cortex across two or more AZ you'll automatically inherit the challenge of maintaining the egress traffic costs. It's recommended to enable compression for the distributor -> ingester communication (`-ingester.client.grpc-use-gzip-compression=true`). This is basically a trade off between CPU cycles to network traffic and to make it short: it's worth enabling it as the additional CPU usage is cheaper than the network egress traffic which can be compressed.

## Setup on GKE / Google BigTable

### Nodepools

We opted in to run the different workloads in separate Nodepools due to the stateful nature of the ingesters. The ingesters require quite a lot RAM and CPU (if compression is enabled), should not be evicted under any circumstance, nor should they get interfered by noisy neighbours. Also if you use soft (anti)affinity rules (e. g. try to distribute the pods between two AV zones) you can end up in some undesired scheduling where you might have 4 ingesters in zone A and just one ingester in zone B. These were some of the reasons which in my oppinion justify the usage of a dedicated nodepool for these pods.

We ended up with 3 different nodepools:

- **default** (all stateless deployments like ES master, distributor, query components, etc. go here)
- **ingesters** (dedicated nodepool for ingester. Made sure with taints & tolerations)
- **elasticsearch** (dedicated nodepool for elasticsearch data nodes, also enforced with taints & tolerations)

### BigTable storage

#### HDD vs SSD

When using BigTable you always want to choose SSD over HDD storage for Cortex. Cortex greatly benefits from the performance difference and your reads will be roughly 10-20x faster than with HDD.

#### Usage

A Cortex cluster which ingests 300k samples / sec in total (non replicated) approximately requires for each week of ingested metrics ~300GB BigTable storage (220GB for Chunks + 80GB for Indices)

#### Node Count

A single node BigTable cluster can take you pretty far. We were able to ingest 300k metrics / seconds without problems. The single node became a bottleneck for the read performance at some point and thus we migrated to a production cluster (3-nodes). Most of the time the cluster is idling at 10% CPU now. The CPU spikes at big, non-cached queries where it has to load lots of data from BigTable.

#### IAM permissions for accessing BigTable

The Ingester, Table Manager and Querier talk to Google BigTable. Therefore these pods need `roles/bigtable.admin` permissions (admin because the table manager creates and deletes table - you could create more granular roles). After creating the IAM service account, download the JSON and put it into the secret at `/kubernetes/cortex/iam-service-account.yaml`. The service account will then be mounted into the pods and used to communicate with the BigTable cluster.
