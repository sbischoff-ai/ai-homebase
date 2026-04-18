FROM memgraph/memgraph:3.8.1 AS memgraph-tools
FROM ghcr.io/openclaw/openclaw:2026.4.15 AS openclaw-runtime

FROM debian:trixie-slim@sha256:26f98ccd92fd0a44d6928ce8ff8f4921b4d2f535bfa07555ee5d18f61429cf0c

ENV DEBIAN_FRONTEND=noninteractive
ARG TEA_VERSION=v0.9.2

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      docker.io \
      gh \
      git \
      gnupg \
      golang-go \
      jq \
      openssh-client \
      python3 \
      ripgrep \
      tmux && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
      > /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

RUN GOBIN=/usr/local/bin go install code.gitea.io/tea@"${TEA_VERSION}" && \
    npm install -g @steipete/summarize && \
    gh --version && \
    tea --version && \
    tmux -V && \
    node --version && \
    npm --version && \
    summarize --version

COPY --from=openclaw-runtime /usr/local /usr/local
COPY --from=openclaw-runtime /app /app
COPY --from=memgraph-tools /usr/bin/mgconsole /usr/local/bin/mgconsole
COPY reviewer-gitea-init.sh /usr/local/bin/reviewer-gitea-init.sh

RUN useradd --create-home --uid 1000 --shell /bin/bash node && \
    chown -R node:node /app /home/node && \
    npm install -g tokscale && \
    tokscale --version && \
    chmod 0755 /usr/local/bin/reviewer-gitea-init.sh

USER node
WORKDIR /app
