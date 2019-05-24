#!/bin/bash
################################################################################
# This basically launches a container that runs unzip.sh.
# Without mounting $PWD as a volume the only options from the main script
# that makes much sense are the ones that read and write to s3 (or http)
# Usage examples (see unzip.sh for more info on the API, but basically reads
# a zipfile from "zipfile" and writes the unzipped items to the logical
# directory "destination", metadata for the objects written is sent on stdout).
# echo '{"zipfile": "s3://multimedia-dev/CFX/input-data/akismet.2.5.3.zip"}' | ./docker-unzip.sh
# echo '{"zipfile": "s3://multimedia-dev/CFX/input-data/akismet.2.5.3.zip", "destination": "s3://multimedia-dev/CFX/processed-data"}' | ./docker-unzip.sh
################################################################################

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

    #echo "AWS_ACCESS_KEY_ID is set to '$AWS_ACCESS_KEY_ID'"
    #echo "AWS_SECRET_ACCESS_KEY is set to '$AWS_SECRET_ACCESS_KEY'"
    #echo "AWS_DEFAULT_REGION is set to '$AWS_DEFAULT_REGION'"
fi

docker run --rm -i \
    -u $(id -u):$(id -g) \
    -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
    -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
    -e AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} \
    bsdtar-unzip $@

