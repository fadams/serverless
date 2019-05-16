This is an example of creating a Fn function directly from a unix command line tool using hotwrap https://github.com/fnproject/hotwrap to mitigate the runtime container startup penalty.

The use case is "sometimes you need to handle advanced use cases and must take complete control of the creation of the function container image."

Note that to use a unix command line tool like this it is necessary to use hotwrap to provide an FDK. The tutorial https://fnproject.io/tutorials/ContainerAsFunction/ kind of implies that it is possible to run a "non-hot" container but comments in this issue https://github.com/fnproject/fn/issues/1493 say that hotwrap actually is necessary. I had some issues getting the code below working initially, the write up of the journey is here: https://github.com/fnproject/fn/issues/1496

```
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
cat test.zip | docker run --rm -i --entrypoint=/usr/bin/unzip docker-mint.local:5000/unzip-hotwrap:0.0.2 -p -
```
To invoke on the Fn server:
```
cat test.zip | fn invoke archive unzip-hotwrap
```
or via Curl (to Fn in Kubernetes):
```
curl --header "Content-Type: application/octet-stream" --data-binary @test.zip http://10.192.0.2:30090/t/archive/unzip-hotwrap
```
or via Curl (to Fn running standalone):
```
curl --header "Content-Type: application/octet-stream" --data-binary @test.zip http://$(hostname -I | awk '{print $1}'):8080/t/archive/unzip-hotwrap
```
Note the @ to specify test.zip is a filename as using application/octet-stream rather than the default application/x-www-form-urlencoded (see https://curl.haxx.se/docs/manpage.html)


This article https://unix.stackexchange.com/questions/211265/unzip-the-archive-with-more-than-one-entry mentions an 8GB public test archive https://archive.org/download/nycTaxiTripData2013/faredata2013.zip this is still smaller than I want to use, but it's a start.

This zipfile http://downloads.wordpress.org/plugin/akismet.2.5.3.zip is fairly small but has a number of items so can be used to test a streaming unzip to several different locations.

#### Instructions for debugging a hotwrap container locally
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

#### Notes on streaming unzip
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

#### Try bsdtar instead of unzip
I discovered that for a large zip I got an error "zip flag 8 (streaming) is not supported" from busybox and I also couldn't find a way to easily separate the different unzipped items on the stdout stream so now looking at bsdtar.

