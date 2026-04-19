#!/usr/bin/env bash

bootstrap_load_shell_vars() {
  local bootstrap_config_path="$1"
  local bootstrap_shell_vars=""

  if [[ -z "$bootstrap_config_path" ]]; then
    return 0
  fi
  if [[ ! -f "$bootstrap_config_path" ]]; then
    echo "Bootstrap config not found: ${bootstrap_config_path}" >&2
    return 1
  fi

  bootstrap_shell_vars="$(python3 ./scripts/bootstrap-config.py shell-vars --config "$bootstrap_config_path")" || return 1
  eval "$bootstrap_shell_vars"
}

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
