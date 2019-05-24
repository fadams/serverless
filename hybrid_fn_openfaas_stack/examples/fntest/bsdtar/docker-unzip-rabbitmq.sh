#!/bin/bash
################################################################################
# This script launches a container that runs unzip.sh wrapped in a "launcher"
# that listens for messages on a specified AMQP 0.9.1 queue. The messages are
# JSON messages of the API format described in unzip.sh e.g. something like:
# '{"zipfile": "s3://multimedia-dev/CFX/input-data/akismet.2.5.3.zip", "destination": "s3://multimedia-dev/CFX/processed-data"}'
# Arranging for such a message to be delivered to the queue that this service is
# listening on will cause the unzip service to be launched.
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

docker run --rm -it \
    -u $(id -u):$(id -g) \
    -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
    -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
    -e AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} \
    -e AMQP_URL="amqp://$(hostname -I | awk '{print $1}'):5672" \
    -e QUEUE_NAME="bsdtar-unzip" \
    -e RESPONSE_QUEUE_NAME="bsdtar-unzip-response" \
    bsdtar-unzip-rabbitmq

