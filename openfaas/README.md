# Useful Bookmarks

Main project page: https://www.openfaas.com/

Top-level GitHub page: https://github.com/openfaas

**Main development page including Welcome + Getting Started links:** https://github.com/openfaas/faas

Documentation: https://docs.openfaas.com/

CLI: https://github.com/openfaas/faas-cli
CLI guide: https://docs.openfaas.com/cli/install/
Get started with the CLI (blog with examples): https://blog.alexellis.io/quickstart-openfaas-cli/

Tutorials: https://github.com/openfaas/workshop


**OpenFaaS on Kubernetes**
Project page: https://github.com/openfaas/faas-netes

Deployment guide for Kubernetes: https://docs.openfaas.com/deployment/kubernetes/


**Lambda example:** 

This example shows how to run an unmodified AWS Lambda function on OpenFaaS
https://github.com/alexellis/lambda-on-openfaas-poc

Is this finished/tested? No it's just an early proof-of-concept. Some internal pub/sub mechanism is probably required.

I *think* that OpenFaaS is sponsored by VMWare:
From https://www.contino.io/insights/what-is-openfaas-and-why-is-it-an-alternative-to-aws-lambda-an-interview-with-creator-alex-ellis
"Alex Ellis, creator of OpenFaaS, an open source Functions-as-a-Service framework that’s rapidly growing in popularity. Alex has been a Docker Captain since 2016 and recently joined VMware’s Open Source Technology Center to work on OpenFaaS full time."


**Metrics**
"Rather than having to implement their own metrics we’ve built them into the platform (via Prometheus). These metrics are used to drive function scaling. That means that you’re deploying and monitoring your functions in a consistent manner"
