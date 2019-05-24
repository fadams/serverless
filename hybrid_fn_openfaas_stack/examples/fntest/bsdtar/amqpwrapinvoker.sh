#!/bin/bash
################################################################################
# This script should be called by amqpwrap.sh on receipt of an AMQP message.
# This script wraps the actual invocation of the command we want launched on
# receipt of a message. We do this because we want to intercept the real
# command's stdout so we can send that to $RESPONSE_QUEUE_NAME
################################################################################

# Invoke the *actual* command that we wish to run and grab its stdout
response=$($@)

# "log" the response message (question, is this what we want to do?)
echo $response

# Publish the response received from the invoked command, the -r sets the
# message routing key to $RESPONSE_QUEUE_NAME and the message is sent to the
# default direct exchange, which is the AMQP equivalent of sending the message
# directly to the $RESPONSE_QUEUE_NAME queue.
amqp-publish -u $AMQP_URL -r $RESPONSE_QUEUE_NAME -b "$response"

