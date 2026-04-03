#!/usr/bin/env bash
set -euo pipefail

DOCKER_HOST_VALUE="${DOCKER_HOST:-}"
IMAGES=()
IDENTITY_FILE=""
KNOWN_HOSTS_FILE=""

usage() {
  cat <<USAGE
Usage: $0 --docker-host <ssh://user@host:port> --image <image[:tag]> [--image <image[:tag]> ...]

Ensure one or more OpenClaw sandbox images are available on a remote Docker daemon.
Each image must already exist locally; the script streams it to the remote daemon only
when the remote host is missing the image or has a different image ID for the same tag.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --docker-host) DOCKER_HOST_VALUE="$2"; shift 2 ;;
    --identity-file) IDENTITY_FILE="$2"; shift 2 ;;
    --image) IMAGES+=("$2"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$DOCKER_HOST_VALUE" ]]; then
  echo "--docker-host (or DOCKER_HOST env var) is required" >&2
  exit 1
fi

if [[ ${#IMAGES[@]} -eq 0 ]]; then
  echo "At least one --image is required" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker CLI is required" >&2
  exit 1
fi

if [[ "$DOCKER_HOST_VALUE" == ssh://* ]] && ! command -v ssh-keyscan >/dev/null 2>&1; then
  echo "ssh-keyscan is required for ssh:// remote Docker hosts" >&2
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
  if [[ "$DOCKER_HOST_VALUE" != ssh://* ]]; then
    return 0
  fi

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

remote_image_exists_via_ssh() {
  local image="$1"
  local -a ssh_args_array=()
  local arg=""
  while IFS= read -r -d '' arg; do
    ssh_args_array+=("$arg")
  done < <(ssh_args)
  ssh "${ssh_args_array[@]}" -p "$(ssh_port)" "$(ssh_user_host)" \
    "docker image inspect $(printf '%q' "$image") >/dev/null 2>&1"
}

local_image_id() {
  local image="$1"
  docker image inspect --format '{{.Id}}' "$image"
}

remote_image_id_via_ssh() {
  local image="$1"
  local -a ssh_args_array=()
  local arg=""
  while IFS= read -r -d '' arg; do
    ssh_args_array+=("$arg")
  done < <(ssh_args)
  ssh "${ssh_args_array[@]}" -p "$(ssh_port)" "$(ssh_user_host)" \
    "docker image inspect --format '{{.Id}}' $(printf '%q' "$image")" 2>/dev/null
}

copy_image_via_ssh() {
  local archive_path="$1"
  local remote_path="$2"
  local -a ssh_args_array=()
  local arg=""
  while IFS= read -r -d '' arg; do
    ssh_args_array+=("$arg")
  done < <(ssh_args)

  scp "${ssh_args_array[@]}" -P "$(ssh_port)" "$archive_path" "$(ssh_user_host):${remote_path}"
  ssh "${ssh_args_array[@]}" -p "$(ssh_port)" "$(ssh_user_host)" \
    "docker load -i '$remote_path' >/dev/null && rm -f '$remote_path'"
}

for image in "${IMAGES[@]}"; do
  local_id=""
  remote_id=""

  echo "Checking local image: ${image}"
  docker image inspect "$image" >/dev/null
  local_id="$(local_image_id "$image")"

  if [[ "$DOCKER_HOST_VALUE" == ssh://* ]]; then
    if remote_image_exists_via_ssh "$image"; then
      remote_id="$(remote_image_id_via_ssh "$image" || true)"
      if [[ -n "$remote_id" && "$remote_id" == "$local_id" ]]; then
        echo "Remote already has current ${image}"
        continue
      fi
    fi
  elif DOCKER_HOST="$DOCKER_HOST_VALUE" docker image inspect "$image" >/dev/null 2>&1; then
    remote_id="$(DOCKER_HOST="$DOCKER_HOST_VALUE" docker image inspect --format '{{.Id}}' "$image" 2>/dev/null || true)"
    if [[ -n "$remote_id" && "$remote_id" == "$local_id" ]]; then
      echo "Remote already has current ${image}"
      continue
    fi
  fi

  tmp_archive="$(mktemp /tmp/openclaw-remote-image.XXXXXX.tar)"
  trap 'rm -f "${tmp_archive}"' EXIT
  echo "Saving ${image} to ${tmp_archive}"
  docker image save -o "$tmp_archive" "$image"
  echo "Loading ${image} onto ${DOCKER_HOST_VALUE}"
  if [[ "$DOCKER_HOST_VALUE" == ssh://* ]]; then
    remote_archive="/tmp/$(basename "$tmp_archive")"
    copy_image_via_ssh "$tmp_archive" "$remote_archive"
  else
    DOCKER_HOST="$DOCKER_HOST_VALUE" docker image load -i "$tmp_archive" >/dev/null
  fi
  rm -f "$tmp_archive"
  echo "Loaded ${image} onto ${DOCKER_HOST_VALUE}"
done
