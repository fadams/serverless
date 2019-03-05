
Standing up local Kubernetes cluster using kubeadm-dind-cluster:
https://github.com/kubernetes-sigs/kubeadm-dind-cluster

Download preconfigured script from releases
https://github.com/kubernetes-sigs/kubeadm-dind-cluster/releases


wget https://github.com/kubernetes-sigs/kubeadm-dind-cluster/releases/download/v0.1.0/dind-cluster-v1.13.sh
chmod +x dind-cluster-v1.13.sh


This script pulls the required image, does all the necessary set-up and
starts up the cluster with minimum fuss.

The script will pull the kubectl executable, but by default pulls it to
$HOME/.kubeadm-dind-cluster

Either add it to PATH directly via:
export PATH="$HOME/.kubeadm-dind-cluster:$PATH"

or add above to .bashrc

or if, like me, you already have a $HOME/bin directory for local executables
then either symlink to the kubectl in $HOME/.kubeadm-dind-cluster or modify
the KUBECTL_DIR environment variable either as part of launching the script 

KUBECTL_DIR=${HOME}/bin ./dind-cluster-v1.13.sh up

or setting on environment, or by editing the script


If successful launch should finish with something like:
* Access dashboard at: http://127.0.0.1:32768/api/v1/namespaces/kube-system/services/kubernetes-dashboard:/proxy

# Basic cluster test:
kubectl get nodes
NAME          STATUS   ROLES    AGE   VERSION
kube-master   Ready    master   35m   v1.13.0
kube-node-1   Ready    <none>   34m   v1.13.0
kube-node-2   Ready    <none>   34m   v1.13.0


Defaults to a two node cluster. Use NUM_NODES environment variable to change.

NUM_NODES=4 ./dind-cluster-v1.13.sh up

--------------------------------------------------------------------------------

# restart the cluster, this should happen much quicker than initial startup
./dind-cluster-v1.13.sh up

# stop the cluster
./dind-cluster-v1.13.sh down

# remove DIND containers and volumes
./dind-cluster-v1.13.sh clean

--------------------------------------------------------------------------------

From Install for Kubernetes. N.B. this is using kubectl/yaml for a production
version it is recommended to use the Helm instructions.
https://docs.openfaas.com/deployment/kubernetes/


Clone the code
git clone https://github.com/openfaas/faas-netes

Deploy the whole stack
1. First create OpenFaaS namespaces
kubectl apply -f https://raw.githubusercontent.com/openfaas/faas-netes/master/namespaces.yml

2. Deploy OpenFaaS
cd faas-netes && kubectl apply -f ./yaml

--------------------------------------------------------------------------------

The OpenFaaS Portal UI should be visible on 

http://10.192.0.2:31112

Prometheus metrics UI on

http://10.192.0.2:31119

Where http://10.192.0.2 represents the Kubernetes API Gateway IP


The Portal address also represents the gateway address for the OpenFaaS CLI

e.g. you need to do 

faas-cli list -g http://10.192.0.2:31112

or

faas-cli list --gateway http://10.192.0.2:31112

or

OPENFAAS_URL=http://10.192.0.2:31112 faas-cli list

or

export OPENFAAS_URL=http://10.192.0.2:31112
faas-cli list

or otherwise include the correct gateway URL on your PATH


see
https://docs.openfaas.com/deployment/kubernetes/
and
https://github.com/openfaas/workshop/blob/kubernetes-preview/lab1b.md


