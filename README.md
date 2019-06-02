# Cortex Ops

This repository has been created to build a community around operating [Cortex](https://github.com/cortexproject/cortex). Therefore we encourage you to share your learnings, improvement proposals, challenges and failures so that we can learn from each other and ultimately come up with a decent guide about operating Cortex.

**In this repository we seek to provide:**

- A production ready setup which should suit most companies' needs in terms of scale and performance
- Operational knowledge (FAQs, clarifying the microservice architecture)
- Premade monitoring solutions (Grafna dashboards)

Most of the granted information shall serve as inspiration for your own deployment. Due to the complexity and the large variety of configurations it is very likely that this setup does not suit all your needs.

**Note**: This setup uses Google's BigTable without an additional Bucket storage for storing all chunks and indexes.

## Kubernetes deployment

In this repository we use Terraform modules along with the [Terraform Kubernetes Provider](https://www.terraform.io/docs/providers/kubernetes/index.html). While collaborating on Kubernetes manifests would be easier for the community, we can not guarantee that these manifests will actually work. Thus we wanted to share the deployment setup we use in ourselves in production, which is Terraform. If you think you can improve for the Deployment, but you are not certain how to implement this into the Terraform module, please submit an issue.

All deployment files and the corresponding documentation can be found in `./deployment`.

## Grafana Monitoring

To be created..

## Ops Guides

To be created..
