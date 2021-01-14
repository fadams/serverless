# Hybrid Fn and OpenFaaS Stack

This is an attempt at creating a hybrid stack comprising both Oracle Fn and OpenFaaS.

The intention is to see if it is possible to create a Kubernetes cluster that has both Fn and OpenFaaS deployed, with each running the same set of functions, we then have an API Gateway acting as an entrypoint and load-balancing across the functions running in both Fn and OpenFaaS. The idea is to illustrate a "hybrid" serverless system to show that it is possible to minimise (as far as reasonably possible) vendor lock-in to any given platform.

At this stage it is very much a basic proof-of-concept and it is unclear how many of our non-functional requirements such as distributed tracing (see https://opentracing.io/ and https://www.jaegertracing.io/) and other instrumentation can be met "out of the box" by the underlying serverless platforms, but the idea of this stack is that it gives an opportunity to try some of that out relatively simply.

For Kubernetes the stack is using kubeadm-dind-cluster (https://github.com/kubernetes-sigs/kubeadm-dind-cluster) as this lets us easily stand up a **multi-node** Kubernetes cluster on a single host, which will be beneficial when it comes to testing out features such as auto-scaling and self-healing/chaos-behaviour.

For Fn it's best to set the context to point to the required FN\_API\_URL and REGISTRY e.g.
```
fn list contexts
CURRENT	NAME	PROVIDER	API URL			REGISTRY
*	default	default		http://10.192.0.2:30080	docker-mint.local:5000
```
```
fn use context default
```
```
fn update context registry docker-mint.local:5000
```
```
fn update context api-url http://10.192.0.2:30080
```
