# Kubernetes deployment

These Kubernetes manifests should give you an idea how to install Cortex in your environment. Please take note that you must modify some of the manifests as described below.

## Setup on GKE / Google BigTable

### IAM permissions for Cortex components

The Ingester, Table Manager and Querier talk to Google BigTable. Therefore these pods need `roles/bigtable.admin` permissions (admin because the table manager creates and deltes table - you could create more granular roles). After creating the IAM service account, download the JSON and put it into the secret at `/kubernetes/cortex/iam-service-account.yaml`. The service account will then be mounted into the pods and used to communicate with the BigTable cluster.
