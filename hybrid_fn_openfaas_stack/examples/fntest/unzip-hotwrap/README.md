This is an example of creating a Fn function directly from a unix command line tool using hotwrap https://github.com/fnproject/hotwrap to mitigate the runtime container startup penalty.

The use case is "sometimes you need to handle advanced use cases and must take complete control of the creation of the function container image."
```
FROM alpine:latest

# Install hotwrap binary
COPY --from=fnproject/hotwrap:latest /hotwrap /hotwrap 

# unzip - list, test and extract compressed files in a ZIP archive
# With Alpine we don't need to explicitly install anything as unzip is
# provided by busybox.
CMD /usr/bin/unzip -p -

# update entrypoint to use hotwrap, this will wrap the command 
ENTRYPOINT ["/hotwrap"]
```
and func.yaml
```
schema_version: 20180708
name: unzip-hotwrap
version: 0.0.1
runtime: docker
triggers:
- name: unzip-hotwrap
  type: http
  source: /unzip-hotwrap
```

To create an app and deploy the function (from this directory):
```
fn create app archive
fn --verbose deploy --app archive
```

Running these commands will create an app called archive and will build the function and deploy to the server. To show that this is, at its heart, just based on a container that reads stdin and writes to stdout we can invoke the container directly as follows:
```
cat test.zip | docker run --rm -i --entrypoint=usr/bin/unzip docker-mint.local:5000/unzip-hotwrap:0.0.2 -p -
```
To invoke on the Fn server:
```
cat test.zip | fn invoke archive unzip-hotwrap
```
or via Curl:
```
curl --data-binary test.zip http://10.192.0.2:30090/t/archive/unzip-hotwrap
```



Note that unzipping a piped zip is not as straightforward as might first appear - see https://stackoverflow.com/questions/7132514/bash-how-to-unzip-a-piped-zip-file-from-wget-qo/52759718#52759718

> The ZIP file format includes a directory (index) at the end of the archive. This directory says where, within the archive each file is located and thus allows for quick, random access, without reading the entire archive.

> This would appear to pose a problem when attempting to read a ZIP archive through a pipe, in that the index is not accessed until the very end and so individual members cannot be correctly extracted until after the file has been entirely read and is no longer available. As such it appears unsurprising that **most ZIP decompressors simply fail when the archive is supplied through a pipe**.

> The directory at the end of the archive is not the only location where file meta information is stored in the archive. In addition, individual entries also include this information in a local file header, for redundancy purposes.

> Although not every ZIP decompressor will use local file headers when the index is unavailable, the tar and cpio front ends to libarchive (a.k.a. bsdtar and bsdcpio) can and will do so when reading through a pipe:


On my Ubuntu base system I found that
```
cat test.zip | unzip -p -
```
fails with a usage response. Now busybox's unzip can take stdin and extract all the files however
```
cat test.zip | busybox unzip -p -
```
fails with "unzip: lseek: Illegal seek", though apparently this works on Ubuntu 18.10 but fortunately it seems to work with alpine:latest which is what is being used in our function container here.

