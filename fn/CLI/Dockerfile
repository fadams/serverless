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

# fnproject/fn CLI in a Docker container.
# It's a marginal gain over installing directly on the host
# but the install instructions needed sudo and it wasn't clear
# what was being installed and where, so Docker keeps things tidy.

FROM debian:stretch-slim

# Install fnproject/fn CLI note that this can exec Docker commands
# so install docker-ce and bind-mount Docker socket in run command.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
    curl ca-certificates apt-transport-https gnupg2 software-properties-common && \
    # See Quickstart/CLI tool from https://github.com/fnproject/cli
    curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - && \
    apt-key fingerprint 0EBFCD88 && \
    apt-add-repository "deb [arch=amd64] https://download.docker.com/linux/debian stretch stable" && \
    apt-get update && DEBIAN_FRONTEND=noninteractive \
    apt-get install -y docker-ce-cli && \
    curl -LSs https://raw.githubusercontent.com/fnproject/cli/master/install | sh && \
    # Remove the packages used for installation
    apt-get clean && \
    apt-get purge -y \
    curl ca-certificates apt-transport-https gnupg2 software-properties-common \
    tzdata readline-common pinentry-curses && \
    apt-get autoremove -y && \
	rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/usr/local/bin/fn"]

#-------------------------------------------------------------------------------
# Example usage
# 
# Build the image
# docker build -t fn .
#

