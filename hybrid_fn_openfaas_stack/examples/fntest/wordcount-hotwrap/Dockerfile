FROM alpine:latest

# Install hotwrap binary
COPY --from=fnproject/hotwrap:latest /hotwrap /hotwrap 

# wc - print newline, word, and byte counts for each file
# With Alpine we don't need to explicitly install anything as wc is
# provided by busybox.
CMD /usr/bin/wc

# update entrypoint to use hotwrap, this will wrap the command 
ENTRYPOINT ["/hotwrap"]
