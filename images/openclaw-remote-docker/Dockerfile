FROM memgraph/memgraph:3.8.1 AS memgraph-tools
FROM ghcr.io/openclaw/openclaw:2026.4.21 AS openclaw-runtime

FROM debian:trixie-slim@sha256:26f98ccd92fd0a44d6928ce8ff8f4921b4d2f535bfa07555ee5d18f61429cf0c

ENV DEBIAN_FRONTEND=noninteractive
ARG TEA_VERSION=0.9.2

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      docker.io \
      gh \
      git \
      gnupg \
      jq \
      openssh-client \
      python-is-python3 \
      python3 \
      python3-requests \
      python3-yaml \
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

COPY --from=openclaw-runtime /usr/local /usr/local
COPY --from=openclaw-runtime /app /app
COPY --from=memgraph-tools /usr/bin/mgconsole /usr/local/bin/mgconsole
COPY images/openclaw-remote-docker/coder-workspace-init.sh /usr/local/bin/coder-workspace-init.sh
COPY images/openclaw-remote-docker/reviewer-gitea-init.sh /usr/local/bin/reviewer-gitea-init.sh
COPY images/openclaw-remote-docker/openclaw-gateway-start.sh /usr/local/bin/openclaw-gateway-start.sh

RUN mkdir -p /usr/local/lib/openclaw-tools && \
    curl -fsSL "https://gitea.com/gitea/tea/releases/download/v${TEA_VERSION}/tea-${TEA_VERSION}-linux-amd64" \
      -o /usr/local/lib/openclaw-tools/tea.real && \
    chmod 0755 /usr/local/lib/openclaw-tools/tea.real && \
    printf '%s\n' \
      '#!/usr/bin/env sh' \
      'set -eu' \
      'if [ -z "${XDG_CONFIG_HOME:-}" ]; then' \
      '  if [ -n "${OPENCLAW_STATE_DIR:-}" ]; then' \
      '    export XDG_CONFIG_HOME="${OPENCLAW_STATE_DIR%/}/.config"' \
      '  elif [ -n "${OPENCLAW_HOME:-}" ]; then' \
      '    export XDG_CONFIG_HOME="${OPENCLAW_HOME%/}/.config"' \
      '  elif [ "${HOME:-}" = "/home/node" ] && [ -d /home/node/.openclaw ]; then' \
      '    export XDG_CONFIG_HOME="/home/node/.openclaw/.config"' \
      '  elif [ -n "${HOME:-}" ]; then' \
      '    export XDG_CONFIG_HOME="${HOME%/}/.config"' \
      '  fi' \
      'fi' \
      'exec /usr/local/lib/openclaw-tools/tea.real "$@"' \
      > /usr/local/bin/tea && \
    chmod 0755 /usr/local/bin/tea && \
    npm install -g @steipete/summarize && \
    summarize_path="$(command -v summarize)" && \
    summarize_real_path="$(readlink -f "${summarize_path}")" && \
    rm -f "${summarize_path}" && \
    printf '%s\n' \
      '#!/usr/bin/env sh' \
      'set -eu' \
      'state_dir="${OPENCLAW_STATE_DIR:-${OPENCLAW_HOME:-}}"' \
      'if [ -z "${state_dir}" ] && [ "${HOME:-}" = "/home/node" ] && [ -d /home/node/.openclaw ]; then' \
      '  state_dir=/home/node/.openclaw' \
      'fi' \
      'if [ -n "${state_dir}" ]; then' \
      '  mkdir -p "${state_dir%/}/.summarize"' \
      '  export HOME="${state_dir%/}"' \
      'else' \
      '  mkdir -p "${HOME%/}/.summarize"' \
      'fi' \
      "exec \"${summarize_real_path}\" \"\$@\"" \
      > "${summarize_path}" && \
    chmod 0755 "${summarize_path}" && \
    gh --version && \
    tea --version | grep -F "${TEA_VERSION}" >/dev/null && \
    tmux -V && \
    node --version && \
    npm --version && \
    summarize --version && \
    useradd --create-home --uid 1000 --shell /bin/bash node && \
    ln -sfn /home/node/.openclaw/.config/tea /home/node/.tea && \
    ln -sfn /home/node/.openclaw/.config/git/config /home/node/.gitconfig && \
    chown -R node:node /app /home/node && \
    npm install -g tokscale && \
    tokscale --version && \
    chmod 0755 /usr/local/bin/coder-workspace-init.sh /usr/local/bin/reviewer-gitea-init.sh /usr/local/bin/openclaw-gateway-start.sh

USER node
WORKDIR /app
