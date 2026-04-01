FROM openclaw-sandbox:bookworm-slim

USER root

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      nodejs \
      npm && \
    npm install -g neo4j-driver && \
    rm -f /usr/local/bin/mgconsole && \
    rm -rf /var/lib/apt/lists/*

USER sandbox
WORKDIR /home/sandbox
