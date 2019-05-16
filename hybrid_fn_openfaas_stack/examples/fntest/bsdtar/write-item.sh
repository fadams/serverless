#!/bin/bash
################################################################################
# This script is intended to be called by the gnu tar --to-command option
# https://www.gnu.org/software/tar/manual/html_node/Writing-to-an-External-Program.html#SEC87
#
# When this option is used, instead of creating the untarred files, tar invokes
# the specified command and pipes the contents of the files to its stdout,
# which can then be read by the executed command's stdin (e.g. this script).
#
# TODO improve logging, error handling etc.
#
################################################################################

#echo $destination

path="$(dirname "$TAR_FILENAME")"
file="$(basename "$TAR_FILENAME")"

#echo "path: $path"
#echo "file: $file"

# Based on the URI of the destination prefix stream the data arriving on stdin
# to the relevant destination (s3/http(s)/file) N.B. only sunny day scenarios
# have been considered so far and there are *many* things that can go wrong with
# s3 or http uploads, so we need to improve error handling and logging somewhat.
if [[ $destination == *"s3://"* ]]; then # Stream data to s3
#    echo "Write to s3"
    cat | aws s3 cp - $destination/$TAR_FILENAME
    retval=$? && [ $retval -ne 0 ] && error="Error $retval writing to "
elif [[ $destination == *"http://"* || $destination == *"https://"* ]]; then # Stream data to http/s
#    echo "Write to http"
    # Use curl with a @- argument to accept input from a pipe.
    cat | curl --header "Content-Type: application/octet-stream" --data-binary @- $destination/$TAR_FILENAME
    retval=$? && [ $retval -ne 0 ] && error="Error $retval writing to "
else # Stream data to filesystem
#    echo "Write to filesystem"
    mkdir -p $destination/$path && cat >"$TAR_FILENAME"
    retval=$? && [ $retval -ne 0 ] && error="Error $retval writing to "
fi

if [ $retval -eq 0 ]; then # OK
    printf "{\"name\": \"$file\", \"size\": $TAR_SIZE, \"uri\": \"$destination/$TAR_FILENAME\"}"
else # Error
    printf "{\"name\": \"$file\", \"size\": $TAR_SIZE, \"error\": \"$error$destination/$TAR_FILENAME\"}"
fi

