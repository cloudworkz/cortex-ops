# Cortex Ops

This repository has been created to build a community around operating [Cortex](https://github.com/cortexproject/cortex). Therefore we encourage you to share your learnings, improvement proposals, challenges and failures so that we can learn from each other and ultimately come up with a decent guide about operating Cortex.

**In this repository we seek to provide:**

- A production ready setup (created for GKE + BigTable) which should suit most companies' needs in terms of scale and performance
- Operational knowledge (FAQs, clarifying the microservice architecture)
- Premade monitoring solutions (Grafna dashboards)

Most of the granted information shall serve as inspiration for your own deployment. Due to the complexity and the large variety of configurations it is very likely that this setup does not suit all your needs.

**Note**: This setup uses Google's BigTable without an additional Bucket storage for storing all chunks and indexes.

## Kubernetes deployment

All deployment files and the corresponding documentation can be found in `./kubernetes`. It has been tested on GKE and built for the usage of BigTable as underlying time series database.

## Grafana Monitoring

To be created..

## Ops Guides

To be created..
