#!/usr/bin/env bash
set -euo pipefail

DOCKER_HOST_VALUE="${DOCKER_HOST:-}"
IDENTITY_FILE=""
KNOWN_HOSTS_FILE=""
REGISTRY_HOST=""
REGISTRY_USERNAME=""
REGISTRY_PASSWORD=""
SOURCE_IMAGES=()
TARGET_IMAGES=()

usage() {
  cat <<USAGE
Usage: $0 --docker-host <ssh://user@host:port> --registry-host <host> --registry-username <user> --registry-password <password> --source-image <image[:tag]> --target-image <registry/namespace/image[:tag]> [--source-image ... --target-image ...]

Log into the registry from the OpenClaw remote Docker host, tag the provided source images, and push them to their canonical registry references.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --docker-host) DOCKER_HOST_VALUE="$2"; shift 2 ;;
    --identity-file) IDENTITY_FILE="$2"; shift 2 ;;
    --registry-host) REGISTRY_HOST="$2"; shift 2 ;;
    --registry-username) REGISTRY_USERNAME="$2"; shift 2 ;;
    --registry-password) REGISTRY_PASSWORD="$2"; shift 2 ;;
    --source-image) SOURCE_IMAGES+=("$2"); shift 2 ;;
    --target-image) TARGET_IMAGES+=("$2"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$DOCKER_HOST_VALUE" || -z "$REGISTRY_HOST" || -z "$REGISTRY_USERNAME" || -z "$REGISTRY_PASSWORD" ]]; then
  echo "docker host plus registry host/credentials are required" >&2
  exit 1
fi

if [[ ${#SOURCE_IMAGES[@]} -eq 0 || ${#SOURCE_IMAGES[@]} -ne ${#TARGET_IMAGES[@]} ]]; then
  echo "matching --source-image and --target-image arguments are required" >&2
  exit 1
fi

if [[ "$DOCKER_HOST_VALUE" != ssh://* ]]; then
  echo "Only ssh:// remote Docker hosts are supported by this helper" >&2
  exit 1
fi

ssh_user_host() {
  local ssh_target="${DOCKER_HOST_VALUE#ssh://}"
  printf '%s\n' "${ssh_target%%:*}"
}

ssh_port() {
  local ssh_target="${DOCKER_HOST_VALUE#ssh://}"
  local ssh_port="${ssh_target##*:}"
  if [[ "$ssh_target" == "$ssh_port" ]]; then
    ssh_port="22"
  fi
  printf '%s\n' "$ssh_port"
}

ssh_args() {
  local ssh_args=(-o BatchMode=yes -o StrictHostKeyChecking=yes)
  if [[ -n "$KNOWN_HOSTS_FILE" ]]; then
    ssh_args+=(-o "UserKnownHostsFile=${KNOWN_HOSTS_FILE}" -o GlobalKnownHostsFile=/dev/null)
  fi
  if [[ -n "$IDENTITY_FILE" ]]; then
    ssh_args+=(-i "$IDENTITY_FILE")
  fi
  printf '%s\0' "${ssh_args[@]}"
}

prepare_known_hosts() {
  local host_line host
  host_line="$(ssh_user_host)"
  host="${host_line#*@}"
  KNOWN_HOSTS_FILE="$(mktemp /tmp/openclaw-remote-known-hosts.XXXXXX)"
  ssh-keyscan -p "$(ssh_port)" "$host" >"$KNOWN_HOSTS_FILE" 2>/dev/null
  if [[ ! -s "$KNOWN_HOSTS_FILE" ]]; then
    echo "Failed to collect host key for ${host}:$(ssh_port) with ssh-keyscan" >&2
    exit 1
  fi
}

cleanup() {
  if [[ -n "$KNOWN_HOSTS_FILE" && -f "$KNOWN_HOSTS_FILE" ]]; then
    rm -f "$KNOWN_HOSTS_FILE"
  fi
}

trap cleanup EXIT
prepare_known_hosts

ssh_run() {
  local -a ssh_args_array=()
  local arg=""
  while IFS= read -r -d '' arg; do
    ssh_args_array+=("$arg")
  done < <(ssh_args)
  ssh "${ssh_args_array[@]}" -p "$(ssh_port)" "$(ssh_user_host)" "$@"
}

for source_image in "${SOURCE_IMAGES[@]}"; do
  ssh_run "docker image inspect $(printf '%q' "$source_image") >/dev/null 2>&1"
done

ssh_run "printf '%s' $(printf '%q' "$REGISTRY_PASSWORD") | docker login $(printf '%q' "$REGISTRY_HOST") --username $(printf '%q' "$REGISTRY_USERNAME") --password-stdin >/dev/null"

for i in "${!SOURCE_IMAGES[@]}"; do
  source_image="${SOURCE_IMAGES[$i]}"
  target_image="${TARGET_IMAGES[$i]}"
  ssh_run "docker tag $(printf '%q' "$source_image") $(printf '%q' "$target_image") && docker push $(printf '%q' "$target_image") >/dev/null"
done
