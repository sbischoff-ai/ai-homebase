FROM ghcr.io/openclaw/openclaw:2026.3.13-1

USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends docker.io openssh-client && \
    rm -rf /var/lib/apt/lists/*

USER node
