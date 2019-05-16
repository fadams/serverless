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
name: bsdtar
version: 0.0.1
runtime: docker
triggers:
- name: bsdtar
  type: http
  source: /bsdtar
```

To create an app and deploy the function (from this directory):
```
fn create app archive
fn --verbose deploy --app archive
```

Running these commands will create an app called archive and will build the function and deploy to the server. To show that this is, at its heart, just based on a container that reads stdin and writes to stdout we can invoke the container directly as follows:
```
cat test.zip | docker run --rm -i --entrypoint=/usr/bin/unzip docker-mint.local:5000/bsdtar:0.0.2 -p -
```
To invoke on the Fn server:
```
cat test.zip | fn invoke archive bsdtar
```
or via Curl (to Fn in Kubernetes):
```
curl --header "Content-Type: application/octet-stream" --data-binary @test.zip http://10.192.0.2:30090/t/archive/bsdtar
```
or via Curl (to Fn running standalone):
```
curl --header "Content-Type: application/octet-stream" --data-binary @test.zip http://$(hostname -I | awk '{print $1}'):8080/t/archive/bsdtar
```
Note the @ to specify test.zip is a filename as using application/octet-stream rather than the default application/x-www-form-urlencoded (see https://curl.haxx.se/docs/manpage.html)


This article https://unix.stackexchange.com/questions/211265/unzip-the-archive-with-more-than-one-entry mentions an 8GB public test archive https://archive.org/download/nycTaxiTripData2013/faredata2013.zip this is still smaller than I want to use, but it's a start.

This http://downloads.wordpress.org/plugin/akismet.2.5.3.zip is fairly small but has a number of items so can be used to test a streaming unzip to several different locations.

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

