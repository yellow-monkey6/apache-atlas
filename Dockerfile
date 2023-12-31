# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM ubuntu:22.04 as base

# Install Git, which is missing from the Ubuntu base images.
RUN apt-get update && apt-get install -y git python3.11 wget

# Install Java.
RUN apt-get update && apt-get install -y openjdk-11-jdk
ENV JAVA_HOME /usr/lib/jvm/java-11-openjdk-amd64

# Install Maven.

RUN apt-get update && apt-get install -y maven
ENV MAVEN_HOME /usr/share/maven

# Add Java and Maven to the path.
ENV PATH /usr/java/bin:/usr/local/apache-maven/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ARG ATLAS_VERSION

FROM base as builder
# Working directory
WORKDIR /root

# Pull down Atlas and build it into /root/atlas-bin.
#RUN git clone https://github.com/apache/atlas.git 
#RUN cd atlas && git checkout tags/$TAG 
RUN wget https://dlcdn.apache.org/atlas/${ATLAS_VERSION}/apache-atlas-${ATLAS_VERSION}-sources.tar.gz
RUN tar zxvf apache-atlas-${ATLAS_VERSION}-sources.tar.gz && mv apache-atlas-sources-${ATLAS_VERSION} atlas

RUN echo 'package-lock=false' >> ./atlas/.npmrc
RUN echo 'package-lock.json' >> ./atlas/.gitignore

# Memory requirements
ENV MAVEN_OPTS "-Xms2g -Xmx2g"
RUN export MAVEN_OPTS="-Xms2g -Xmx2g"

# Remove -DskipTests if unit tests are to be included
RUN cd atlas && mvn -e -DskipTests \
    -Dmaven.wagon.http.ssl.ignore.validity.dates=true \
    -Dmaven.wagon.http.ssl.allowall=true \
    -Dmaven.wagon.http.ssl.insecure=true \
    -Drat.numUnapprovedLicenses=200 \
    -Pdist,embedded-hbase-solr  clean install
#RUN cd atlas && mvn clean install -e -DskipTests=true -Drat.numUnapprovedLicenses=200 -Pdist,embedded-hbase-solr -f pom.xml
RUN mkdir -p /root/atlas-bin
RUN tar xzf /root/atlas/distro/target/*bin.tar.gz --strip-components 1 -C /root/atlas-bin

FROM base
WORKDIR /root/atlas-bin
COPY --from=builder /root/atlas-bin ./
RUN groupadd atlas && \
    useradd -g atlas -ms /bin/bash atlas && \
    chown -R atlas:atlas /root

# Set env variables, add it to the path, and start Atlas.
ENV MANAGE_LOCAL_SOLR true
ENV MANAGE_LOCAL_HBASE true
ENV PATH /root/atlas-bin/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RUN ln -s /usr/bin/python3 /usr/bin/python
RUN ln -s /usr/bin/pip3 /usr/bin/pip

EXPOSE 21000

USER atlas

CMD ["/bin/bash", "-c", "python bin/atlas_start.py"]
