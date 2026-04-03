FROM memgraph/memgraph:3.8.1 AS memgraph-tools

FROM ghcr.io/openclaw/openclaw:2026.3.28

USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends docker.io jq openssh-client ripgrep && \
    rm -rf /var/lib/apt/lists/*
COPY --from=memgraph-tools /usr/bin/mgconsole /usr/local/bin/mgconsole

RUN npm install -g tokscale && \
    tokscale --version

USER node
