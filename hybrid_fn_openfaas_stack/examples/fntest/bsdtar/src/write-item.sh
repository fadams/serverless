#!/bin/bash
################################################################################
# This script is intended to be called by the gnu tar --to-command option
# https://www.gnu.org/software/tar/manual/html_node/Writing-to-an-External-Program.html#SEC87
#
# When this option is used, instead of creating the untarred files, tar invokes
# the specified command and pipes the contents of the files to its stdout,
# which can then be read by the executed command's stdin (e.g. this script).
#
################################################################################

function log() {
    if [[ $1 != "DEBUG" || ($1 == "DEBUG" && ! -z ${DEBUG+x}) ]]; then
        >&2 echo "[$(date -Iseconds)] $1 - ${item_id} : $2"
    fi
}

path="$(dirname "$TAR_FILENAME")"
file="$(basename "$TAR_FILENAME")"

# Based on the URI of the destination prefix stream the data arriving on stdin
# to the relevant destination (s3/http(s)/file) N.B. only sunny day scenarios
# have been considered so far and there are *many* things that can go wrong with
# s3 or http uploads, so we need to improve error handling and logging somewhat.
if [[ $destination == *"s3://"* ]]; then # Stream data to s3
    log DEBUG "Writing to aws s3 location $destination/$TAR_FILENAME"
    response=$(cat | aws s3 cp - $destination/$TAR_FILENAME 2>&1)
    retval=$?
elif [[ $destination == *"http://"* || \
        $destination == *"https://"* ]]; then # Stream data to http/s
    log DEBUG "Writing to http resource $destination/$TAR_FILENAME"
    # Use curl with a @- argument to accept input from a pipe.
    response=$(cat | curl -s --header "Content-Type: application/octet-stream" --data-binary @- $destination/$TAR_FILENAME 2>&1)
    retval=$?
else # Stream data to filesystem
    log DEBUG "Writing $destination/$TAR_FILENAME to local filesystem"
    response=$(mkdir -p $destination/$path 2>&1 && cat 2>&1 >"$destination/$TAR_FILENAME")
    retval=$?
fi

if [ $retval -eq 0 ]; then # OK
    printf "{\"name\": \"$file\", \"size\": $TAR_SIZE, \"uri\": \"$destination/$TAR_FILENAME\"}"
else # Error
    error="Error $retval writing to $destination/$TAR_FILENAME: $response"
    log ERROR "$error"
    printf "{\"name\": \"$file\", \"size\": $TAR_SIZE, \"error\": \"$error\"}"
fi

