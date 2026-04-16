#!/usr/bin/env bash

append_bootstrap_resolve_hosts() {
  local -n cmd_ref="$1"
  local -A seen=()
  local host_var=""
  local host_value=""

  for host_var in \
    OPENCLAW_HOST \
    NEXTCLOUD_HOST \
    NEXTCLOUD_MCP_HOST \
    NEXTCLOUD_PUBLIC_HOST \
    QDRANT_HOST \
    QDRANT_MCP_HOST \
    MEMGRAPH_HOST \
    MEMGRAPH_LAB_HOST \
    GITEA_HOST \
    REGISTRY_HOST \
    ARGOCD_HOST \
    VAULTWARDEN_HOST \
    PAPERLESS_HOST
  do
    host_value="${!host_var:-}"
    if [[ -z "$host_value" || -n "${seen[$host_value]:-}" ]]; then
      continue
    fi
    seen[$host_value]=1
    cmd_ref+=(--resolve-host "$host_value")
  done
}
