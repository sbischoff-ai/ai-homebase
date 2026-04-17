# syntax=docker/dockerfile:1.7

FROM memgraph/memgraph:3.8.1 AS memgraph-tools

FROM debian:trixie-slim@sha256:26f98ccd92fd0a44d6928ce8ff8f4921b4d2f535bfa07555ee5d18f61429cf0c

ENV DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,id=openclaw-sandbox-bookworm-apt-cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,id=openclaw-sandbox-bookworm-apt-lists,target=/var/lib/apt,sharing=locked \
  apt-get update \
  && apt-get upgrade -y --no-install-recommends \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    gh \
    gnupg \
    golang-go \
    jq \
    python3 \
    ripgrep \
  && mkdir -p /etc/apt/keyrings \
  && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
  && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*

COPY --from=memgraph-tools /usr/bin/mgconsole /usr/local/bin/mgconsole
COPY reviewer-gitea-init.sh /usr/local/bin/reviewer-gitea-init.sh

RUN GOBIN=/usr/local/bin go install code.gitea.io/tea@latest \
  && npm install -g @steipete/summarize \
  && gh --version \
  && tea --version \
  && node --version \
  && npm --version \
  && summarize --version

RUN useradd --create-home --shell /bin/bash sandbox && \
    usermod --home /workspace/.home sandbox && \
    mkdir -p /workspace/.home && \
    chown -R sandbox:sandbox /workspace && \
    chmod 0755 /usr/local/bin/reviewer-gitea-init.sh

USER sandbox
WORKDIR /workspace

CMD ["sleep", "infinity"]
