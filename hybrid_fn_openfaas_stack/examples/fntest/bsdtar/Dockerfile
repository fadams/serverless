FROM alpine:latest

# Install hotwrap binary
COPY --from=fnproject/hotwrap:latest /hotwrap /hotwrap 

# unzip - list, test and extract compressed files in a ZIP archive
# With Alpine we don't need to explicitly install anything as unzip is
# provided by busybox. Note that the CMD needs to be using the JSON
# array form https://docs.docker.com/engine/reference/builder/
# as below, using the shell form can result in a syntax error for unzip.
CMD ["/usr/bin/unzip -p -"]

# update entrypoint to use hotwrap, this will wrap the command 
ENTRYPOINT ["/hotwrap"]
