#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
# 
#   http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

# Launch fnproject/fnserver serverless/FaaS framework.
# The docker run options were grokked from the code for "fn start"
# https://github.com/fnproject/cli/blob/master/commands/start.go#L57-L67
# This tries to avoid --privileged though some things might require it.
# The iofs stuff isn't documented anywhere but is necessary or fn invoke
# fails and errors with the message:
# {"message":"Container initialization timed out, 
# please ensure you are using the latest fdk / format and check the logs"}
# It runs without --entrypoint=./fnserver but generates several warnings
# It looks like the default entrypoint is used for "Docker in Docker".
docker run --rm -i \
    --name fnserver \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -p 8080:8080 \
    -v ${PWD}/data:/app/data \
    -v ${PWD}/iofs:/iofs \
    -e FN_IOFS_DOCKER_PATH=${PWD}/iofs \
    -e FN_IOFS_PATH=/iofs \
    --entrypoint=./fnserver \
    fnproject/fnserver

