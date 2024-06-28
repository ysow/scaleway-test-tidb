# Use a base image with required dependencies
FROM ubuntu:20.04

# Install required packages
RUN apt-get update && \
    apt-get install -y curl tar wget mysql-client

# Install TiUP
RUN curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh

# Add TiUP to PATH
ENV PATH=$PATH:/root/.tiup/bin

# Install tiup bench component
RUN tiup install bench

RUN echo 2

COPY tpch /tpch

WORKDIR /tpch/

ENTRYPOINT ["/tpch/entrypoint.sh"]
