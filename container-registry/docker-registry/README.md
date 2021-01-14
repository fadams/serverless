# docker-registry

This directory contains instructions and a script for standing up an instance of the basic [Docker Registry](https://docs.docker.com/registry/). This example is just a "toy" registry for experiments to avoid having to use the public Docker Hub. Clearly for production a more production ready private repository is required.

### Some Useful resources
- https://docs.docker.com/registry/
- https://docs.docker.com/registry/deploying/
- https://docs.docker.com/registry/insecure/
- https://hub.docker.com/_/registry
- https://kind.sigs.k8s.io/docs/user/local-registry/
- https://kind.sigs.k8s.io/docs/user/private-registries/
- https://github.com/kubernetes-sigs/kubeadm-dind-cluster/issues/56

### Basic Registry
The most basic registry may be launched as follows:
```
docker run --rm -d \
    --name registry \
    -p 5000:5000 \
    registry:2
```
This will launch an insecure registry bound to port 5000. To test it:
```
docker pull ubuntu
docker tag ubuntu localhost:5000/ubuntu
docker push localhost:5000/ubuntu
```
The private network IP address of the local machine (e.g. `hostname -I | awk '{print $1}'`) may also be used as follows:
```
docker pull ubuntu
docker tag ubuntu $(hostname -I | awk '{print $1}'):5000/ubuntu
docker push $(hostname -I | awk '{print $1}'):5000/ubuntu
```
Remember of course that this registry is insecure.....

### Using Self-signed Certificates with IP Addresses
The Docker documentation on using [self-signed certificates](https://docs.docker.com/registry/insecure/#use-self-signed-certificates) assumes that a Fully Qualified Domain Name (like myregistrydomain.com) may be used as the Certificate Common Name (CN). For local testing however, it is common to want to use an IP address.

The information in this section was gleaned from the following resources:

- https://naveensnayak.com/2017/05/08/self-signed-certificates-with-san/
- https://bowerstudios.com/node/1007
- https://support.citrix.com/article/CTX135602
- https://hackernoon.com/create-a-private-local-docker-registry-5c79ce912620
- https://blog.container-solutions.com/adding-self-signed-registry-certs-docker-mac

The gist is to use the openssl configuration file usually found in `/etc/ssl/openssl.cnf`as a starting point and add the required IP address as an alt name:
```
First

cp /etc/ssl/openssl.cnf .

Then modify the copy of openssl.cnf as follows:


1. uncomment (by removing the hash mark)
   req_extensions = v3_req # The extensions to add to a certificate request
2. Modify the v3_req section as follows:
   [ v3_req ]

   # Extensions to add to a certificate request

   basicConstraints = CA:FALSE
   keyUsage = nonRepudiation, digitalSignature, keyEncipherment

   [ v3_ca ]
   subjectAltName=@alt_names

 3. Add the following to the end of the copy of openssl.cnf 

   [alt_names]
   IP.1 = 192.168.0.12 # Substitute required IP address here
```
The example above assumes that `hostname -I | awk '{print $1}'` is 192.168.0.12, the actual value should of course be substituted.

In order to create the certificates from the newly created configuration file:
```
mkdir -p certs
```
Then (using the value derived from running `hostname -I | awk '{print $1}'` as the CN when asked)
```
openssl req -newkey rsa:4096 -nodes -sha256 -keyout certs/domain.key -x509 -days 365 -out certs/domain.crt -config openssl.cnf
```
Verify that the result is as expected using:
```
openssl x509 -in certs/domain.crt -noout -text
```
A registry using the newly created certificates may be launched as follows:
```
docker run --rm -d \
    --name registry \
    -v $PWD/certs:/certs \
    -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
    -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
    -p 443:443 \
    registry:2
```
In order to use this registry however, it is necessary to instruct every Docker daemon that wishes to use the registry to trust that certificate, as per the documentation on [self-signed certificates](https://docs.docker.com/registry/insecure/#use-self-signed-certificates).

On Linux (for this example) first run:
```
sudo mkdir -p /etc/docker/certs.d/192.168.0.12
```
To create a certs.d directory under /etc/docker (if it doesn't already exist) and under that create a directory 192.168.0.12, or substitute `hostname -I | awk '{print $1}'`).

The copy the certs/domain.crt we created earlier as follows (again substituting the actual required IP from `hostname -I | awk '{print $1}'`):
```
sudo cp certs/domain.crt /etc/docker/certs.d/192.168.0.12/ca.crt
```
With Docker for Mac apparently the above approach doesn't work and the way to do it is to add the certificate to the Mac's keychain (from the [Docker for Mac documentation](https://docs.docker.com/docker-for-mac/#add-client-certificates)):
```
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca.crt
```
or alternatively, to add the certificate to a local keychain only (rather than for all users),
```
security add-trusted-cert -d -r trustRoot -k ~/Library/Keychains/login.keychain ca.crt
```
The change will take effect after restarting Docker for Mac.
