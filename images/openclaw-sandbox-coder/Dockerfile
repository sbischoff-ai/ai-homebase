FROM openclaw-sandbox:trixie-slim

USER root

ARG DEBIAN_FRONTEND=noninteractive
ARG UV_INSTALL_DIR=/usr/local/bin
ENV CARGO_HOME=/usr/local/cargo
ENV RUSTUP_HOME=/usr/local/rustup
ENV PATH=/usr/local/cargo/bin:/usr/local/go/bin:${PATH}

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      bash \
      build-essential \
      ca-certificates \
      curl \
      file \
      git \
      jq \
      less \
      make \
      openssh-client \
      pkg-config \
      procps \
      python3 \
      python3-pip \
      python3-venv \
      ripgrep \
      tmux \
      unzip \
      xz-utils \
      yq \
      zip && \
    rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="${UV_INSTALL_DIR}" sh

RUN curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal && \
    rustc --version && cargo --version

RUN npm install -g @openai/codex@0.118.0 && \
    codex --version

RUN npm install -g tokscale && \
    tokscale --version

RUN curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash && \
    helm version --short

COPY coder-init.sh /usr/local/bin/coder-init.sh

RUN usermod --home /workspace/.home sandbox && \
    mkdir -p /workspace/.home && \
    ln -sfn /workspace/.home /home/sandbox && \
    chown -R sandbox:sandbox /workspace && \
    chmod 0755 /usr/local/bin/coder-init.sh

USER sandbox
WORKDIR /workspace
