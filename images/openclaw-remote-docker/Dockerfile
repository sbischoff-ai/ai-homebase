FROM ghcr.io/openclaw/openclaw:2026.3.28

USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends docker.io jq openssh-client ripgrep && \
    rm -rf /var/lib/apt/lists/*
RUN curl -sSf "https://install.memgraph.com" | sh

USER node
