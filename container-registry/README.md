# container-registry

In order to run FaaS platforms locally on Kubernetes it is useful to have a private container registry running so that we can avoid pushing the containers for our functions to a public repository like DockerHub.

The [docker-registry](docker-registry/README.md) directory contains instructions and a script for standing up an instance of the basic [Docker Registry](https://docs.docker.com/registry/)

The [quay](quay/README.md) directory is a work-in-progress to eventually contain instructions and a script for standing up a Kubernetes cluster hosting a [projectquay](https://www.projectquay.io/) registry, which is is the open source distribution of Red Hat Quay.