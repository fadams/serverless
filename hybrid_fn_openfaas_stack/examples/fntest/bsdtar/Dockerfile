# This Dockerfile is used by the fn deployment. It's not clear if it is
# possible to specify an alternative Dockerfile name for fn, so for now we use
# the default name Dockerfile for deployments to fn.

FROM alpine:latest

# Install hotwrap binary
COPY --from=fnproject/hotwrap:latest /hotwrap /hotwrap

# Install the streaming unzip scripts from src directory to /usr/local/bin
COPY src/unzip.sh /usr/local/bin
COPY src/write-item.sh /usr/local/bin

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

#-------------------------------------------------------------------------------
# This Dockerfile is intended to be used by the Fn deploy mechanism e.g. 
# fn create app archive
# fn --verbose deploy --app archive
# will create an app called archive on the Fn server and build and deploy
# the function defined by this Dockerfile and func.yaml

