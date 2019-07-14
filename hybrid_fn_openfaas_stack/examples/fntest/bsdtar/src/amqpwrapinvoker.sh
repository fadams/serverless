#!/bin/bash
################################################################################
# This script should be called by amqpwrap.sh on receipt of an AMQP message.
# This script wraps the actual invocation of the command we want launched on
# receipt of a message. We do this because we want to intercept the real
# command's stdout so we can send that to $RESPONSE_QUEUE_NAME
################################################################################

# Read AMQP Headers into variables
while read line
do
    # break if the line is empty
    [ -z "$line" ] && break
    
    key=$(echo $line | cut -d':' -f1)
    value=$(echo $line | cut -d':' -f2 | awk '{$1=$1};1') # trim whitespace
    eval $key=$value # Set $key as an environment variable
done

#>&2 echo "------------------------------------------"
#>&2 echo "$AMQP_REPLY_TO"
#>&2 echo "$AMQP_CORRELATION_ID"
#>&2 echo "------------------------------------------"

# Invoke the *actual* command that we wish to run and grab its stdout
response=$($@)

# To log the response message set DEBUG=true in environment
#echo $response

# Publish the response received from the invoked command, the -r sets the
# message routing key to $AMQP_REPLY_TO and the message is sent to the
# default direct exchange, which is the AMQP equivalent of sending the message
# directly to the $AMQP_REPLY_TO queue. The -i sets the message correlation ID.
amqp-publish -u $AMQP_URL -r $AMQP_REPLY_TO -i $AMQP_CORRELATION_ID -b "$response"

