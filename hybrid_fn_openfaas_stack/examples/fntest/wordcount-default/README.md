This is an example of creating a Fn function directly from a unix command line tool rather than via an FDK. In this example we will be using the Fn "default container contract" which was illustrated in the tutorial https://fnproject.io/tutorials/ContainerAsFunction/.

The use case is "sometimes you need to handle advanced use cases and must take complete control of the creation of the function container image."

The default container contract allows unmodified containers that receive input on stdin and sent output to stdout to be used as Fn functions, however the cost is that these functions are not "hot" and so may carry a runtime container startup penalty.

An alternative approach called "hotwrap" can mitigate this and is illustrated in another example. Hotwrap implements the Fn FDK contract and takes advantage of Fn's streaming event model inside your container, but the down side is that it requires a modified container entrypoint.

This example uses a fairly trivial Dockerfile and provides essentially the same functionality as the OpenFaaS wordcount function provided in https://github.com/openfaas/faas/blob/master/stack.yml whose Dockerfile is here https://github.com/openfaas/faas/blob/master/sample-functions/WordCountFunction/Dockerfile:
```
FROM alpine:latest

# wc - print newline, word, and byte counts for each file
# With Alpine we don't need to explicitly install anything as wc is
# provided by busybox.
CMD /usr/bin/wc
```
and func.yaml
```
schema_version: 20180708
name: wordcount
version: 0.0.1
runtime: docker
triggers:
- name: wordcount
  type: http
  source: /wordcount
```

To create an app and deploy the function (from this directory):
```
fn create app wordcount
fn --verbose deploy --app wordcount
```

Running these commands will create an app called wordcount and will build the function and deploy to the server. To show that this is, at its heart, just based on a container that reads stdin and writes to stdout we can invoke the container directly as follows (the -n on echo omits the trailing newline so the wc result only covers what is within the quotes)
```
echo -n $'some\nlines\nof\ntext' | docker run --rm -i docker-mint.local:5000/wordcount:0.0.2
        3         4        18
```
To invoke on the Fn server:
```
echo -n $'some\nlines\nof\ntext' | fn invoke wordcount wordcount
```

Error invoking function. status: 502 message: container failed to initialize, please ensure you are using the latest fdk / format and check the logs
