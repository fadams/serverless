#!/bin/bash
################################################################################
# A microservice/function to perform a streamed unzip operation, pulling
# data from the specified URI then doing a streamed convert of zip to gnutar
# using bsdtar/libarchive, so that we can then use tar's --to-command option to
# write each item to a separate URI. It is a bit of a faff but gnutar doesn't
# handle zip, but conversely bsdtar doesn't support the --to-command option.
#
# The general form of the commands being used internally by this script are:
# cat <zipfile> | bsdtar -cf - --format gnutar @- | tar --to-command ./write-item.sh -xf-
#
# bsdtar is being used to convert the input zip archive to a gnu tar archive
# which is then piped to gnu tar, which uses --to-command to intercept each
# item from the archive so we can write them to the required location.
#
# This script also makes use of aws s3 command line options to stream from/to
# s3 to/from stdin/stdout. This article gives a good explanation of this:
# https://loige.co/aws-command-line-s3-content-from-stdin-or-to-stdout/
# Write to s3 from stdout:
# cat "hello world" | aws s3 cp - s3://some-bucket/hello.txt
# Use data from s3 at input for other commands:
# aws s3 cp s3://some-bucket/hello.txt -
# 
# This script parses JSON input of the form read from stdin:
# {"zipfile": "<zipfile-URI>",
#  "destination": "<bucker-or-directory>"}
#
# The output JSON form written to stdout is:
# {"function": "bsdtar-unzip",
#  "parent-object": "<zipfile-path>",
#  "child-objects": [{"name": "<name1>", "size": <size1>, "uri", "<item-URI1>"},
#                    {"name": "<name2>", "size": <size2>, "uri", "<item-URI2>"},
#                    ...]}
#
# This script requires the packages libarchive-tools (for bsdtar), jq and curl
# it also requires the aws-cli to be installed in order to use s3.
#
# TODO logging, error handling etc.
#
################################################################################

# Usage examples:
# echo '{"zipfile": "test.zip"}' | ./unzip.sh
# echo '{"zipfile": "akismet.2.5.3.zip"}' | ./unzip.sh
# echo '{"zipfile": "s3://multimedia-dev/CFX/input-data/akismet.2.5.3.zip"}' | ./unzip.sh
# echo '{"zipfile": "http://downloads.wordpress.org/plugin/akismet.2.5.3.zip"}' | ./unzip.sh
# echo '{"zipfile": "https://downloads.wordpress.org/plugin/akismet.2.5.3.zip"}' | ./unzip.sh
# echo '{"zipfile": "https://archive.org/download/nycTaxiTripData2013/faredata2013.zip"}' | ./unzip.sh

# echo '{"zipfile": "akismet.2.5.3.zip", "destination": "s3://multimedia-dev/CFX/processed-data"}' | ./unzip.sh
# echo '{"zipfile": "akismet.2.5.3.zip", "destination": "http://skaro.local:8080"}' | ./unzip.sh
# echo '{"zipfile": "s3://multimedia-dev/CFX/input-data/akismet.2.5.3.zip", "destination": "s3://multimedia-dev/CFX/processed-data"}' | ./unzip.sh


# S3 URLs used for testing
# s3://<s3-bucket>/input-data
# s3://<s3-bucket>/processed-data

################################################################################

# TODO perhaps support passing zipfile by value on stdin, to do this we'd need
# to be able to check stdin is not JSON without swallowing any of it so that
# can subsequently pass all of it to the bsdtar call.

# Read stdin into input so we can parse zipfile and destination from the JSON.
input=$(cat)

# Use jq to parse the zipfile and destination properties from the JSON input.
zipfile=$(echo $input | jq -r '.zipfile')
destination=$(echo $input | jq -r '.destination')

# If destination property is null set it to $PWD for current directory
[[ $destination == null ]] && destination=$PWD || destination=$destination

# TODO use these in debug logs
#echo $input
#echo $zipfile
#echo $destination

# Initialise the JSON output, note that we'll need to append this with the child
# objects representing the metadata for each extracted item.
output="{\"function\": \"bsdtar-unzip\", \"parent-object\": \"$zipfile\", \"child-objects\": ["

# Find the path the unzip.sh script is executing from and use that as the path
# for the write-item.sh script. This should allow us to call unzip.sh from
# any location without worrying about relative paths.
BIN=$(cd $(dirname $0); echo $PWD)

# Make the destination property available to the write-item.sh script.
export destination

# Pipe the zipfile to bsdtar in order to convert from zip to gnu tar format
# then pipe to gnu tar so we can process the tar, which will call write-item.sh
# for every item in the tar, passing the data to that script's stdin.

if [[ $zipfile == *"s3://"* ]]; then # Stream from s3
#    echo "Zipfile from s3"
    children=$(aws s3 cp $zipfile - | bsdtar -cf - --format gnutar @- | tar --to-command $BIN/write-item.sh -xf-)   
elif [[ $zipfile == *"http://"* || $zipfile == *"https://"* ]]; then # Stream from http
#    echo "Zipfile from http"
    # Curl's -s option is silent or quiet mode. Don't show progress meter or
    # error messages so makes Curl mute. The -L means location so if the server
    # reports that the requested page has moved to a different location
    # (indicated with a Location: header and a 3XX response code), this option
    # will make curl redo the request on the new place.
    children=$(curl -s -L $zipfile | bsdtar -cf - --format gnutar @- | tar --to-command $BIN/write-item.sh -xf-)
else # Stream from filesystem
#    echo "Zipfile from filesystem"
    children=$(cat $zipfile | bsdtar -cf - --format gnutar @- | tar --to-command $BIN/write-item.sh -xf-)
fi

# The metadata string from the untar process needs to have commas inserted
# between each JSON object in the array.
children=${children//"}{"/"}, {"}

# Finish up the JSON output and write to stdout.
output="$output$children]}"
echo $output

