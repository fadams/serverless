This is an example of creating a Fn function directly from a unix command line tool using hotwrap https://github.com/fnproject/hotwrap to mitigate the runtime container startup penalty.

The use case is "sometimes you need to handle advanced use cases and must take complete control of the creation of the function container image."

Note that to use a unix command line tool like this it is necessary to use hotwrap to provide an FDK. The tutorial https://fnproject.io/tutorials/ContainerAsFunction/ kind of implies that it is possible to run a "non-hot" container but comments in this issue https://github.com/fnproject/fn/issues/1493 say that hotwrap actually is necessary. I had some issues getting the code below working initially, the write up of the journey is here: https://github.com/fnproject/fn/issues/1496

### Streaming unzip
Initial experiments with streaming unzip used busybox unzip, but it was discovered that for a large zip an error "zip flag 8 (streaming) is not supported" was reported from busybox. An additional issue was that for multi-item zipfiles a way couldn't be found to easily separate the different unzipped items on the stdout stream, hence the investigation into bsdtar.

**list contents using busybox unzip**
```
cat akismet.2.5.3.zip | busybox unzip -l -
```

**extract to stdout using busybox unzip**
```
cat akismet.2.5.3.zip | busybox unzip -p -
```

**Extract specific file (obtained from -l option) to stdout**
```
cat akismet.2.5.3.zip | busybox unzip -p - akismet/readme.txt
```
All work fine, however list contents of 8GB archive - fails with "zip flag 8 (streaming) is not supported".
```
curl -L https://archive.org/download/nycTaxiTripData2013/faredata2013.zip | busybox unzip -p -
```

### bsdtar experiments
The next focus was trying bsdtar to get over "zip flag 8 (streaming) is not supported".

Note that in x mode (extract), all POSIX-compliant versions of tar require -f to read the input archive from somewhere other than the default. To read from stdin, POSIX also requires that you give - as the file name.

**list contents**
```
cat akismet.2.5.3.zip | bsdtar -tf-
```
```
cat faredata2013.zip | bsdtar -tf-
```
```
curl -s -L https://archive.org/download/nycTaxiTripData2013/faredata2013.zip | bsdtar -tf-
```

**Extract to stdout**
```
cat akismet.2.5.3.zip | bsdtar --to-stdout -xf-
```
```
cat faredata2013.zip | bsdtar --to-stdout -xf-
```
```
curl -s -L https://archive.org/download/nycTaxiTripData2013/faredata2013.zip | bsdtar --to-stdout -xf-
```

**Better formatting**

The problem with just using `--to-stdout` is that none of the path info is preserved, nor is there any way of identifying where to split the items in a multi-file archive. The first thought was to try and get the path emitted on stderr so that post processing may be possible.

The following does indeed emit the path on stderr and the items on stdout, but it's still non-trivial to use this approach to separate each item, especially from a script.

See https://unix.stackexchange.com/questions/394125/print-the-content-of-each-file-in-a-tar-archive
> -s = Modify file or archive member names according to pattern

> trailing p specifies that after a successful substitution the original path name and the new	path name should be printed to standard	error

> trailing H, R, or S characters suppress substitutions for hardlink targets, regular filenames, or symlink targets, respectively.
```
cat akismet.2.5.3.zip | bsdtar --to-stdout -xf- -s'/.*/ /pHS'
```
```
cat faredata2013.zip | bsdtar --to-stdout -xf- -s'/.*/ /pHS'
```

**Try bsdtar built-in format conversion**

When trying to figure out a better approach the following article was found in the gnu tar manual https://www.gnu.org/software/tar/manual/html_node/Writing-to-an-External-Program.html#SEC87. This implies that it is possible to use the `tar --to-command` option.

Unfortunately however bsdtar doesn't support that option and gnu tar doen't handle zip.....

The next approach tried was to use bsdtar/libarchive to do a streamed conversion to gnutar format then pipe the converted gnutar stream to `tar --to-command ./command.sh`

Basic instructions are in the bsdtar man page: https://www.freebsd.org/cgi/man.cgi?query=bsdtar&sektion=1&manpath=FreeBSD+5.3-stable and https://www.freebsd.org/cgi/man.cgi?query=libarchive-formats&sektion=5&apropos=0&manpath=FreeBSD+12.0-RELEASE+and+Ports


Convert the zip to a gnutar file just to check the resulting tar archive looks OK
```
cat akismet.2.5.3.zip | bsdtar -czf- --format gnutar @- > temp.tar
```

Now do a streamed convert of zip to gnutar using bsdtar/libarchive so we can then use tar's --to-command option to write each item to a separate file.
```
cat test.zip | bsdtar -cf - --format gnutar @- | tar --to-command ./write-item.sh -xf-
```
```
cat akismet.2.5.3.zip | bsdtar -cf- --format gnutar @- | tar --to-command ./write-item.sh -xf-
```
```
cat awscli-bundle.zip | bsdtar -cf- --format gnutar @- | tar --to-command ./write-item.sh -xf-
```

This one doesn't work however as files don't have size metadata
```
cat faredata2013.zip | bsdtar -cf- --format gnutar @- | tar --to-command ./write-item.sh -xf-
```

This may be of interest too, but it hasn't yet been investigated https://github.com/mafintosh/tar-stream

So the basic approach above gets wrapped up into two scripts `unzip.sh` and `write-item.sh`, the first of these take the ideas above and puts some code around to parse a simple JSON command format and adds support for things like streaming the zip input from AWS S3.

The following Dockerfile turns all of that into a function that can be hosted on the Fn serverless framework.
```
FROM alpine:latest

# Install hotwrap binary
COPY --from=fnproject/hotwrap:latest /hotwrap /hotwrap

# Install the streaming unzip scripts from current directory to /usr/local/bin
COPY unzip.sh /usr/local/bin
COPY write-item.sh /usr/local/bin

# Install the packages needed by the bsdtar unzip scripts.
# Note that we're installing the full tar package as busybox tar does not
# support the --to-command option necessary for the correct functioning of
# the unzip script. Note too that aws-cli is not yet released to a stable
# alpine version, it is only the in edge/testing repository, so need to install
# in a more manual way - found ideas here https://github.com/mesosphere/aws-cli
RUN apk update && apk upgrade && \
    apk add bash curl tar libarchive-tools jq \
    python py-pip groff && \
    pip install --upgrade awscli==1.14.5 s3cmd==2.0.1 python-magic && \
    apk -v --purge del py-pip && \
    rm -rf /var/cache/apk/*

CMD ["/usr/local/bin/unzip.sh"]

# Update entrypoint to use hotwrap, this will wrap the command 
ENTRYPOINT ["/hotwrap"]
```
and func.yaml
```
schema_version: 20180708
name: bsdtar
version: 0.0.1
runtime: docker
triggers:
- name: bsdtar
  type: http
  source: /bsdtar
```

N.B. This function requires AWS CLI credentials in order to acces s3. One
approach is to add a "config" block to the func.yaml as described in the docs
https://github.com/fnproject/docs/blob/master/fn/develop/func-file.md, e.g.
```
config:
  AWS_ACCESS_KEY_ID: <AWS_ACCESS_KEY_ID>
  AWS_SECRET_ACCESS_KEY: <AWS_SECRET_ACCESS_KEY>
  AWS_DEFAULT_REGION: <AWS_DEFAULT_REGION>
```
That works, but one issue is how best to protect that info as it's not something
that one necessarily wants pushed to configuration management - especially not
to a public server! It's possible to mitigate this in part with a .gitignore,
but a better method *might* be to use the fn CLI as described here:
https://github.com/fnproject/docs/blob/master/fn/develop/configs.md.
This approach makes it possible to write a script to extract the creds from
a more private location (or even just from the local environment) and push
the info to the app or function.

To create an app and deploy the function (from this directory) and update the
config with AWS config/creds from the environment or from the .aws directory:
```
# Check if AWS_ACCESS_KEY_ID is set, if not try to get the values of the
# creds and region from the .aws credentials and config files.
if [ -z ${AWS_ACCESS_KEY_ID+x} ]; then 
    if [ -d "$HOME/.aws" ]; then
        # The cut splits on = and the sed strips surrounding whitespace
        AWS_ACCESS_KEY_ID=$(cat $HOME/.aws/credentials | grep "aws_access_key_id" | cut -d'=' -f2 | sed -e 's/^[ \t]*//')
        AWS_SECRET_ACCESS_KEY=$(cat $HOME/.aws/credentials | grep "aws_secret_access_key" | cut -d'=' -f2 | sed -e 's/^[ \t]*//')
        AWS_DEFAULT_REGION=$(cat $HOME/.aws/config | grep "region" | cut -d'=' -f2 | sed -e 's/^[ \t]*//')
    else
        echo "Can't find aws CLI credentials in either environment or $HOME/.aws."
    fi
fi

# Create the app and build & deploy the function
fn create app archive
fn --verbose deploy --app archive

# Set AWS CLI creds as app config, as per
# https://github.com/fnproject/docs/blob/master/fn/develop/configs.md
fn config app archive AWS_ACCESS_KEY_ID ${AWS_ACCESS_KEY_ID}
fn config app archive AWS_SECRET_ACCESS_KEY ${AWS_SECRET_ACCESS_KEY}
fn config app archive AWS_DEFAULT_REGION ${AWS_DEFAULT_REGION}
```

Running these commands will create an app called archive and will build the function and deploy to the server then set the AWS CLI creds.

To invoke on the Fn server:
```
echo '{"zipfile": "s3://multimedia-dev/CFX/input-data/akismet.2.5.3.zip", "destination": "s3://multimedia-dev/CFX/processed-data"}' | fn invoke archive bsdtar
```
or via Curl (to Fn in Kubernetes):
```
curl -H "Content-Type: application/json" -d '{"zipfile": "s3://multimedia-dev/CFX/input-data/akismet.2.5.3.zip", "destination": "s3://multimedia-dev/CFX/processed-data"}' http://10.192.0.2:30090/t/archive/bsdtar
```
or via Curl (to Fn running standalone):
```
curl -H "Content-Type: application/json" -d '{"zipfile": "s3://multimedia-dev/CFX/input-data/akismet.2.5.3.zip", "destination": "s3://multimedia-dev/CFX/processed-data"}' http://$(hostname -I | awk '{print $1}'):8080/t/archive/bsdtar
```

### Instructions for debugging a hotwrap container locally
Make a directory to be the UNIX socket filesystem

mkdir iofs

Launch the function in your local docker instance

docker run -d --name function --rm -e FN_FORMAT=http-stream -e FN_LISTENER=unix:/iofs/lsnr.sock -v ${PWD}/iofs:/iofs <function-image>:<image-tag>

Launch a client container (this can be skipped if running docker locally on linux)

docker run -it --rm -v ${PWD}/iofs:/iofs oraclelinux:7-slim

Invoke the function using curl

curl -v --unix-socket –unix-socket ${PWD}/iofs/lsnr.sock -H "Fn-Call-Id: 0000000000000000" -H "Fn-Deadline: 9999-01-01T00:00:00.000Z" http://function/call

Cleanup
Kill the function container

docker kill function

Remove the iofs directory

rm -rf iofs

### Using AMQP as an alternative approach to serverless
Taking the idea of hotwrap as a container ENTRYPOINT, as an alternative to a serverless framework it is possible to provide an analogous AMQP wrapper.

The Dockerfile `Dockerfile-rabbitmq` creates a container image for the bsdtar-unzip that includes "amqpwrap" as an analogous concept to hotwrap, this basically listens on a specified queue then invokes CMD when a message is received, the `unzip.sh` and `write-item.sh` are exactly the same as the serverless implementation as the primary contract is sending data via stdin/stdout.

The script `docker-unzip-rabbitmq.sh` stands up the service, this is mostly just a docker run command that passes a bunch of required environment variables to the container. N.B. it is all currently pretty "sunny day", so if an AMQP broker isn't running or the relevant queues aren't present it will simply fail rather that attempt to reconnect etc.

The script `rabbitmq-broker.sh` stands up a containerised broker using the rabbitmq:3-management image from DockerHub, it listens for AMQP 0.9.1 connections on port 5672 and management connections on port 15672 and the UI can be connected to from a browser pointing to localhost:15672. When the broker is up and running the service requires the queue `bsdtar-unzip` as the main queue that requests are sent down and `bsdtar-unzip-response` as the response queue.

Note that the request/response mechanism is currently pretty primitive and needs some thinking about and in particular there almost certainly needs to be a correlation_id passed between the request and response messages so message invokers can associate command requests with their subsequent responses on an asynchronous system.

Still not convinced by RabbitMQ, though to be fair the UI is quite nice. I'd like to compare performancew with things like Qpid (and maybe ActiveMQ) and also look as AMQP 1.0, as that provides much better interoperability between vendors. Indeed it feels worth looking at "cloud native" messaging such as NATS too, as that might be easier to wrap in a way that looks to clients like AWS SQS.

Still also somewhat convinced that making use of one or more off the shelf serverless frameworks is likely to be a better bet than trying to roll our own. If we **do** roll our own we definitely should make use of the sort of patterns employed by serverless frameworks such as the main function contract being over stdin/stdout as this is the way most likely to ensure that the core microservice business logic can be built in a polyglot, container-native way.

