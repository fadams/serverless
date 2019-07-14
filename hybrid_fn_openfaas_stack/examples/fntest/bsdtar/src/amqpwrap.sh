#!/bin/bash
################################################################################
# This script acts as a "wrapper" similar to the Fn hotwrap program. The idea
# is that it is run as a container ENTRYPOINT where it connects to an AMQP
# broker at URL $AMQP_URL and listens for messages on queue $QUEUE_NAME. When
# a message arrives that message is sent to the application specified in the
# container's CMD via its stdin. When the container sends its response via
# stdout that is then published to $RESPONSE_QUEUE_NAME.
#
# The actual invocation of $CMD is itself wrapped by amqpwrapinvoker.sh the
# reason for this is that amqp-consume takes a command as a call-back, but we
# also want to be able to intercept the stdout of $CMD and write that to
# $RESPONSE_QUEUE_NAME. We can't simply do the following:
# response=$(amqp-consume -u $AMQP_URL -q $QUEUE_NAME $CMD)
# because amqp-consume blocks so we won't see the stdout from $CMD until we
# quit if we try that, so instead we use amqpwrapinvoker.sh as the command
# triggered by  amqp-consume.
#
# The basis for this code is the amqp-tools package, which is a set of CLI
# tools for AMQP 0.9.1/RabbitMQ.
# https://stackoverflow.com/questions/4545660/rabbitmq-creating-queues-and-bindings-from-a-command-line
# amqp-publish -u amqp://192.168.202.143 -r test_queue -b "hello world"
# amqp-get -u amqp://192.168.202.143 -q test_queue
# amqp-consume -u amqp://192.168.202.143 -q test_queue cat
# amqp-publish -u amqp://192.168.202.143 -r test_queue -b '{"zipfile": "s3://multimedia-dev/CFX/input-data/akismet.2.5.3.zip", "destination": "s3://multimedia-dev/CFX/processed-data"}'
# amqp-consume -u amqp://192.168.202.143 -q test_queue /usr/local/bin/unzip.sh
#
#
# TODO this is very much a simple proof of concept, a real asynchronous
# AMQP request/response pattern is likely to need a correlation_id so that
# responses can be tied to the original requests and it's not clear that the
# CLI tools from the amqp-tools package support the use of correlation_id
# TBH if this amqpwrapper approach ultimately feels like a good model it might
# be best to write a statically compiled standalone executable to minimise
# the dependencies to be placed on the actual application container.
################################################################################

# Grok the Docker CMD that this wrapper (as the ENTRYPOINT) should be using.
CMD=$@
#echo "$AMQP_URL"
#echo "$QUEUE_NAME"
#echo "$RESPONSE_QUEUE_NAME"

# Call amqp-consume to connect to $AMQP_URL and do a blocking read of messages
# off $QUEUE_NAME. When a message arrives amqpwrapinvoker.sh is called with
# $CMD as a parameter and the message body is sent to its stdin. The
# amqpwrapinvoker.sh allows $CMD's stdout to be captured and published to
# $RESPONSE_QUEUE_NAME.
amqp-consume -u $AMQP_URL -q $QUEUE_NAME -d -p 100 /usr/local/bin/amqpwrapinvoker.sh $CMD

