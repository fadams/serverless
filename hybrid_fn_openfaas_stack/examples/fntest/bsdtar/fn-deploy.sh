#!/bin/bash
################################################################################
# This script gets the various AWS CLI creds and config either from the
# environment or from the ~/.aws/credentials and ~/.aws/config files, it then
# creates the archive app deploys the function then updates the app config
# with the AWS CLI info that has been harvested.
# This approach avoids the need to store the AWS CLI info unnecessarily.
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
fi

# Create the app and build & deploy the function
fn create app archive
fn --verbose deploy --app archive

# Set AWS CLI creds as app config, as per
# https://github.com/fnproject/docs/blob/master/fn/develop/configs.md
if [ ! -z ${AWS_ACCESS_KEY_ID+x} ]; then 
    fn config app archive AWS_ACCESS_KEY_ID ${AWS_ACCESS_KEY_ID}
    fn config app archive AWS_SECRET_ACCESS_KEY ${AWS_SECRET_ACCESS_KEY}
    fn config app archive AWS_DEFAULT_REGION ${AWS_DEFAULT_REGION}
fi
