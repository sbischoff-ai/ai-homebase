# syntax=docker/dockerfile:1.7

FROM memgraph/memgraph:3.8.1 AS memgraph-tools
FROM ghcr.io/openclaw/openclaw:2026.4.21 AS openclaw-runtime

FROM debian:trixie-slim@sha256:26f98ccd92fd0a44d6928ce8ff8f4921b4d2f535bfa07555ee5d18f61429cf0c

ENV DEBIAN_FRONTEND=noninteractive
ARG TEA_VERSION=0.9.2

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
    jq \
    python-is-python3 \
    python3 \
    python3-pip \
    python3-requests \
    python3-yaml \
    ripgrep \
  && mkdir -p /etc/apt/keyrings \
  && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
  && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends nodejs \
  && pip3 install --break-system-packages --no-cache-dir neo4j \
  && rm -rf /var/lib/apt/lists/*

COPY --from=memgraph-tools /usr/bin/mgconsole /usr/local/bin/mgconsole
COPY --from=openclaw-runtime /app/skills /app/skills
COPY charts/openclaw/files/mcp-http-bridge.mjs /opt/openclaw-runtime/mcp/mcp-http-bridge.mjs
COPY images/openclaw-sandbox-base/reviewer-gitea-init.sh /usr/local/bin/reviewer-gitea-init.sh

RUN mkdir -p /usr/local/lib/openclaw-tools \
  && curl -fsSL "https://gitea.com/gitea/tea/releases/download/v${TEA_VERSION}/tea-${TEA_VERSION}-linux-amd64" \
    -o /usr/local/lib/openclaw-tools/tea.real \
  && chmod 0755 /usr/local/lib/openclaw-tools/tea.real \
  && printf '%s\n' \
    '#!/usr/bin/env sh' \
    'set -eu' \
    'if [ -z "${XDG_CONFIG_HOME:-}" ]; then' \
    '  if [ -n "${OPENCLAW_STATE_DIR:-}" ]; then' \
    '    export XDG_CONFIG_HOME="${OPENCLAW_STATE_DIR%/}/.config"' \
    '  elif [ -n "${OPENCLAW_HOME:-}" ]; then' \
    '    export XDG_CONFIG_HOME="${OPENCLAW_HOME%/}/.config"' \
    '  elif [ -n "${HOME:-}" ]; then' \
    '    export XDG_CONFIG_HOME="${HOME%/}/.config"' \
    '  fi' \
    'fi' \
    'exec /usr/local/lib/openclaw-tools/tea.real "$@"' \
    > /usr/local/bin/tea \
  && chmod 0755 /usr/local/bin/tea \
  && npm install -g @steipete/summarize \
  && summarize_path="$(command -v summarize)" \
  && summarize_real_path="$(readlink -f "${summarize_path}")" \
  && rm -f "${summarize_path}" \
  && printf '%s\n' \
    '#!/usr/bin/env sh' \
    'set -eu' \
    'state_dir="${OPENCLAW_STATE_DIR:-${OPENCLAW_HOME:-}}"' \
    'if [ -n "${state_dir}" ]; then' \
    '  mkdir -p "${state_dir%/}/.summarize"' \
    '  export HOME="${state_dir%/}"' \
    'else' \
    '  mkdir -p "${HOME%/}/.summarize"' \
    'fi' \
    "exec \"${summarize_real_path}\" \"\$@\"" \
    > "${summarize_path}" \
  && chmod 0755 "${summarize_path}" \
  && gh --version \
  && tea --version | grep -F "${TEA_VERSION}" >/dev/null \
  && node --version \
  && npm --version \
  && summarize --version

RUN useradd --create-home --shell /bin/bash sandbox && \
    usermod --home /workspace/.home sandbox && \
    mkdir -p /workspace/.home && \
    chown -R sandbox:sandbox /workspace /app/skills && \
    chmod 0755 /usr/local/bin/reviewer-gitea-init.sh

USER sandbox
WORKDIR /workspace

CMD ["sleep", "infinity"]
