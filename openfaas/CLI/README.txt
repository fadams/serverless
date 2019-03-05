Install the faas-cli

#curl -sL https://cli.openfaas.com | sudo sh
curl -sL https://cli.openfaas.com | sh

WARNING:
The documents say: "If you run the script as a normal non-root user then the script will be downloaded to the current folder." but the example it gives uses sudo sh which installs to /usr/local/bin

Either add to PATH directly or add to .bashrc

or if, like me, you already have a $HOME/bin directory for local executables
then either symlink to the faas-cli or copy to $HOME/bin


TODO
Create Dockerised install of CLI to avoid any accidental installing to /usr/local/bin

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

