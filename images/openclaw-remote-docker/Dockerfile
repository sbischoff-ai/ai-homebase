FROM memgraph/memgraph:3.8.1 AS memgraph-tools
FROM ghcr.io/openclaw/openclaw:2026.4.9 AS openclaw-runtime

FROM debian:trixie-slim@sha256:26f98ccd92fd0a44d6928ce8ff8f4921b4d2f535bfa07555ee5d18f61429cf0c

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      docker.io \
      jq \
      openssh-client \
      ripgrep && \
    rm -rf /var/lib/apt/lists/*

COPY --from=openclaw-runtime /usr/local /usr/local
COPY --from=openclaw-runtime /app /app
COPY --from=memgraph-tools /usr/bin/mgconsole /usr/local/bin/mgconsole

RUN useradd --create-home --uid 1000 --shell /bin/bash node && \
    chown -R node:node /app /home/node && \
    npm install -g tokscale && \
    tokscale --version

USER node
WORKDIR /app
