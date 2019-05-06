This is an example of creating a Fn function directly from a unix command line tool using hotwrap https://github.com/fnproject/hotwrap to mitigate the runtime container startup penalty.

The use case is "sometimes you need to handle advanced use cases and must take complete control of the creation of the function container image."

This example uses a fairly trivial Dockerfile and provides essentially the same functionality as the OpenFaaS wordcount function provided in https://github.com/openfaas/faas/blob/master/stack.yml whose Dockerfile is here https://github.com/openfaas/faas/blob/master/sample-functions/WordCountFunction/Dockerfile:
```
FROM alpine:latest

# Install hotwrap binary
COPY --from=fnproject/hotwrap:latest /hotwrap /hotwrap 

# wc - print newline, word, and byte counts for each file
# With Alpine we don't need to explicitly install anything as wc is
# provided by busybox.
CMD /usr/bin/wc

# update entrypoint to use hotwrap, this will wrap the command 
ENTRYPOINT ["/hotwrap"]
```
and func.yaml
```
schema_version: 20180708
name: wordcount-hotwrap
version: 0.0.1
runtime: docker
triggers:
- name: wordcount-hotwrap
  type: http
  source: /wordcount-hotwrap
```

To create an app and deploy the function (from this directory):
```
fn create app wordcount
fn --verbose deploy --app wordcount
```

Running these commands will create an app called wordcount and will build the function and deploy to the server. To show that this is, at its heart, just based on a container that reads stdin and writes to stdout we can invoke the container directly as follows (the -n on echo omits the trailing newline so the wc result only covers what is within the quotes)
```
echo -n $'some\nlines\nof\ntext' | docker run --rm -i --entrypoint=/usr/bin/wc docker-mint.local:5000/wordcount-hotwrap:0.0.2
        3         4        18
```
To invoke on the Fn server:
```
echo -n $'some\nlines\nof\ntext' | fn invoke wordcount wordcount-hotwrap
        3         4        18
```
or via Curl:
```
curl -d $'some\nlines\nof\ntext' http://10.192.0.2:30090/t/wordcount/wordcount-hotwrap
        3         4        18
```
Note that $'some\nlines\nof\ntext' is using bash ANSI-C Quoting http://www.gnu.org/software/bash/manual/html_node/ANSI_002dC-Quoting.html#ANSI_002dC-Quoting to allow backslash-escaped characters to be replaced as specified by the ANSI C standard. Without this the wc result will come back as:
```
        0         1        21
```
as the shell will pass \n to curl as `\` followed by `n` rather than a newline, see.
