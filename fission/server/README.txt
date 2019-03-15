
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

Fission Installation:
https://docs.fission.io/installation/

For a production version it is recommended to use the Helm instructions.
https://docs.fission.io/installation/#set-up-helm
https://docs.fission.io/installation/#install-fission-if-you-have-helm


Install Fission – alternative method without helm
https://docs.fission.io/installation/#install-fission-alternative-method-without-helm



# Full Fission install:
$ kubectl apply -f https://github.com/fission/fission/releases/download/1.0.0/fission-all-1.0.0.yaml


Deploying fission-all-1.0.0.yaml to kubeadm-dind-cluster didn't seem to work. On the Dashboard Deployments window we have errors:

controller:
MountVolume.SetUp failed for volume "config-volume" : couldn't propagate object cache: timed out waiting for the condition
Readiness probe failed: Get http://10.244.2.7:8888/healthz: dial tcp 10.244.2.7:8888: connect: connection refused
Back-off restarting failed container 


fission-1-0-0-prometheus-alertmanager:
pod has unbound immediate PersistentVolumeClaims (repeated 2 times)

fission-1-0-0-prometheus-server:
pod has unbound immediate PersistentVolumeClaims (repeated 2 times)





# Full install on minikube:
$ kubectl apply -f https://github.com/fission/fission/releases/download/1.0.0/fission-all-1.0.0-minikube.yaml


This seemed to partially work at least

controller:
Readiness probe failed: Get http://10.244.2.4:8888/healthz: dial tcp 10.244.2.4:8888: connect: connection refused

The prometheus errors were the same (and they could be related to the controller failure)


However, The controller did *seem* to come up eventually though, though the prometheus errors remained.

The documentation is a bit unclear about what "good looks like", not sure yet if there is a UI similar to the OpenFaaS one (which is nice as it gives a bit of confidence that it's actually working).

When I tried a second time the controller didn't seem to start even waiting for 30 minutes or so so it may have been a fluke that this started at all...


Running:
fission env create --name nodejs --image fission/node-env:1.0.0

gives

Fatal error: Error forwarding to controller port: error upgrading connection: the server does not allow this method on the requested resource




fission --server http://10.192.0.2:31313/ env create --name nodejs --image fission/node-env:1.0.0

returned

environment 'nodejs' created

Which seems positive - hopefully there is an environment variable for server URL to avoid needing the --server flag on every call...




If it was consistently working on the MiniKube version my guess would be that the issue is to do with a difference between serviceType = NodePort versus ClusterIP or LoadBalancer.
I believe for example that OpenFaaS defaults to NodePort for simplicity so that it "just works" for MiniKube and OpenFaaS "just works" for kubeadm-dind-cluster too. But as 
kubectl apply -f https://github.com/fission/fission/releases/download/1.0.0/fission-all-1.0.0-minikube.yaml
Is unreliable too (though sometimes works) I'm not sure???






# Minimal install on minikube:
$ kubectl apply -f https://github.com/fission/fission/releases/download/1.0.0/fission-core-1.0.0-minikube.yaml

Seems to work better - at least the controller seems to be started more consistently, but this time I'm seeing

storagesvc:
pod has unbound immediate PersistentVolumeClaims (repeated 2 times)



fission env create --name nodejs --image fission/node-env:1.0.0
environment 'nodejs' created


curl https://raw.githubusercontent.com/fission/fission/master/examples/nodejs/hello.js > hello.js

fission function create --name hello --env nodejs --code hello.js
Package 'hello-js-ilbi' created
function 'hello' created



fission route create --method GET --url /hello --function hello
trigger '9b2bea97-a250-4208-b722-a21f7742fb3e' created


fission function test --name hello
hello, world!

Pointing browser to router URL: http://10.192.0.2:31314/hello
also displays "hello, world"


So deploying fission-core-1.0.0-minikube.yaml at least the basic QuickStart example works, but I don't like the storagesvc error nor do I understand why this is working more reliably than fission-all-1.0.0-minikube.yaml though figuring that out is currently beyond my Kubernetes skillz.

Now try golang example.

fission env create --name go --image fission/go-env:1.0.0 --builder fission/go-builder:1.0.0
environment 'go' created

curl -LO https://raw.githubusercontent.com/fission/fission/master/examples/go/hello.go


fission function create --name gohello --env go --src hello.go --entrypoint Handler
Package 'hello-go-d3t2' created
function 'gohello' created


fission function test --name gohello
Error calling function gohello: 500; Please try again or fix the error: Error updating service address entry for function gohello_default: Internal error - [gohello] Error creating service for function: Internal error - 500 Internal Server ErrorFatal error: Error querying logs: Post http://127.0.0.1:46847/proxy/influxdb?db=fissionFunctionLog&params=%7B%22funcuid%22%3A%22cab4dece-466f-11e9-bab0-8630ba6a218b%22%2C%22time%22%3A0%7D&q=select+%2A+from+%22log%22+where+%22funcuid%22+%3D+%24funcuid+AND+%22time%22+%3E+%24time+LIMIT+1000: net/http: request canceled (Client.Timeout exceeded while awaiting headers)


Why does this fail???



Tried running
kubectl apply -f https://github.com/fission/fission/releases/download/1.0.0/fission-core-1.0.0-minikube.yaml

on a single node cluster now storagesvc says:
persistentvolumeclaim "fission-storage-pvc" not found

This is a different error than I was seeing with a two node cluster, but I'm still not sure what I am missing (aside from more Kubernetes knowledge). I did note that elsewhere in the events there was a
 
pod has unbound immediate PersistentVolumeClaims 

So it may just be a timing thing why I was seeing different errors with a multi-node cluster, either way this error doesn't instil confidence, but not sure how to resolve it.


Still can't get golang example working...


--------------------------------------------------------------------------------


