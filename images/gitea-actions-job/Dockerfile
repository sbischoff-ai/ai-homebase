FROM openclaw-sandbox:trixie-slim

USER root

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      bash \
      build-essential \
      ca-certificates \
      curl \
      docker.io \
      file \
      git \
      jq \
      make \
      openssh-client \
      procps \
      python3 \
      python3-pip \
      python3-venv \
      unzip \
      xz-utils \
      yq \
      zip && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash && \
    helm version --short

WORKDIR /workspace

CMD ["/bin/bash", "-lc", "sleep infinity"]
