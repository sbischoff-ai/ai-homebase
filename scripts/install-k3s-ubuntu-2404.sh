#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/logging.sh"

TARGET_USER="${TARGET_USER:-${SUDO_USER:-${USER}}}"
HELM_APT_KEY_URL="${HELM_APT_KEY_URL:-https://packages.buildkite.com/helm-linux/helm-debian/gpgkey}"
HELM_APT_REPO_URL="${HELM_APT_REPO_URL:-https://packages.buildkite.com/helm-linux/helm-debian/any/}"
HELM_APT_REPO="/etc/apt/keyrings/helm.gpg"
KUBECTL_APT_KEY_URL="${KUBECTL_APT_KEY_URL:-https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key}"
KUBECTL_APT_REPO_URL="${KUBECTL_APT_REPO_URL:-https://pkgs.k8s.io/core:/stable:/v1.34/deb/}"
KUBECTL_APT_REPO="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
OPENCLAW_SHARED_STATE_DIR="${OPENCLAW_SHARED_STATE_DIR:-/var/lib/ai-homebase/openclaw-state}"
INCUS_BRIDGE_NAME="${INCUS_BRIDGE_NAME:-incusbr0}"
INCUS_BRIDGE_IPV4="${INCUS_BRIDGE_IPV4:-10.10.10.1/24}"
INCUS_BRIDGE_SUBNET="${INCUS_BRIDGE_SUBNET:-10.10.10.0/24}"
INCUS_STORAGE_POOL="${INCUS_STORAGE_POOL:-default}"
INCUS_STORAGE_DRIVER="${INCUS_STORAGE_DRIVER:-dir}"
INCUS_PROFILE_NAME="${INCUS_PROFILE_NAME:-default}"
POLICY_RC_D_PATH="/usr/sbin/policy-rc.d"
POLICY_RC_D_BACKUP=""
POLICY_RC_D_WAS_PRESENT=0

usage() {
  cat <<USAGE
Usage: $0 [options]

Prepare a fresh Ubuntu 24.04 host with the prerequisites for the ai-homebase k3s bootstrap flow.

Options:
  --target-user <name>         User to add to k3s/incus groups (default: ${TARGET_USER})
  --openclaw-shared-state-dir <path>
                               Host path shared later between k3s and the sandbox VM for OpenClaw state (default: ${OPENCLAW_SHARED_STATE_DIR})
  --incus-bridge-name <name>   Incus bridge name to create/reconcile (default: ${INCUS_BRIDGE_NAME})
  --incus-bridge-ipv4 <cidr>   Incus bridge IPv4 CIDR (default: ${INCUS_BRIDGE_IPV4})
  --incus-bridge-subnet <cidr> Incus bridge subnet used for host NAT rules (default: ${INCUS_BRIDGE_SUBNET})
  --incus-storage-pool <name>  Incus storage pool name (default: ${INCUS_STORAGE_POOL})
  --incus-storage-driver <drv> Incus storage driver for a new pool (default: ${INCUS_STORAGE_DRIVER})
  --help                       Show this help message
USAGE
}

download_to_file() {
  local url="$1"
  local output_path="$2"

  curl \
    --fail \
    --silent \
    --show-error \
    --location \
    --retry 5 \
    --retry-delay 2 \
    --retry-all-errors \
    --connect-timeout 10 \
    --output "${output_path}" \
    "${url}"
}

disable_package_service_autostart() {
  if [[ -e "${POLICY_RC_D_PATH}" ]]; then
    POLICY_RC_D_WAS_PRESENT=1
    POLICY_RC_D_BACKUP="$(mktemp)"
    cp -a "${POLICY_RC_D_PATH}" "${POLICY_RC_D_BACKUP}"
  fi

  cat >"${POLICY_RC_D_PATH}" <<'EOF'
#!/bin/sh
exit 101
EOF
  chmod 0755 "${POLICY_RC_D_PATH}"
}

restore_package_service_autostart() {
  if [[ "${POLICY_RC_D_WAS_PRESENT}" -eq 1 && -n "${POLICY_RC_D_BACKUP}" ]]; then
    cp -a "${POLICY_RC_D_BACKUP}" "${POLICY_RC_D_PATH}"
    rm -f "${POLICY_RC_D_BACKUP}"
  else
    rm -f "${POLICY_RC_D_PATH}"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-user) TARGET_USER="$2"; shift 2 ;;
    --openclaw-shared-state-dir) OPENCLAW_SHARED_STATE_DIR="$2"; shift 2 ;;
    --incus-bridge-name) INCUS_BRIDGE_NAME="$2"; shift 2 ;;
    --incus-bridge-ipv4) INCUS_BRIDGE_IPV4="$2"; shift 2 ;;
    --incus-bridge-subnet) INCUS_BRIDGE_SUBNET="$2"; shift 2 ;;
    --incus-storage-pool) INCUS_STORAGE_POOL="$2"; shift 2 ;;
    --incus-storage-driver) INCUS_STORAGE_DRIVER="$2"; shift 2 ;;
    -h|--help|--usage) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root (for example via sudo)." >&2
  exit 1
fi

bootstrap_init_logging

if ! id "${TARGET_USER}" >/dev/null 2>&1; then
  echo "Target user '${TARGET_USER}' does not exist on this host." >&2
  exit 1
fi

TARGET_UID="$(id -u "${TARGET_USER}")"
TARGET_GID="$(id -g "${TARGET_USER}")"

export DEBIAN_FRONTEND=noninteractive

disable_package_service_autostart
trap restore_package_service_autostart EXIT

apt-get update
apt-get install -y --no-install-recommends \
  apt-transport-https \
  ca-certificates \
  curl \
  dnsmasq-base \
  gpg \
  iptables \
  jq \
  openssh-client \
  openssl \
  python3 \
  python3-venv \
  ovmf \
  qemu-system-modules-spice \
  qemu-system-x86 \
  qemu-utils \
  software-properties-common

install -d -m 0755 /etc/apt/keyrings

if [[ ! -f "${HELM_APT_REPO}" ]]; then
  temp_key="$(mktemp)"
  trap 'rm -f "${temp_key}"' EXIT
  download_to_file "${HELM_APT_KEY_URL}" "${temp_key}"
  gpg --dearmor --yes -o "${HELM_APT_REPO}" "${temp_key}"
  rm -f "${temp_key}"
  trap - EXIT
fi
cat >/etc/apt/sources.list.d/helm-stable-debian.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=${HELM_APT_REPO}] ${HELM_APT_REPO_URL} any main
EOF

if [[ ! -f "${KUBECTL_APT_REPO}" ]]; then
  temp_key="$(mktemp)"
  trap 'rm -f "${temp_key}"' EXIT
  download_to_file "${KUBECTL_APT_KEY_URL}" "${temp_key}"
  gpg --dearmor --yes -o "${KUBECTL_APT_REPO}" "${temp_key}"
  rm -f "${temp_key}"
  trap - EXIT
fi
cat >/etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=${KUBECTL_APT_REPO}] ${KUBECTL_APT_REPO_URL} /
EOF

apt-get update
apt-get install -y --no-install-recommends helm kubectl incus incus-agent virtiofsd

install -d -m 0755 /etc/systemd/system/incus.service.d
cat >/etc/systemd/system/incus.service.d/10-ai-homebase-agent-path.conf <<'EOF'
[Service]
Environment=PATH=/usr/libexec/incus:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EOF
systemctl daemon-reload

restore_package_service_autostart
trap - EXIT

cat >/etc/sysctl.d/99-ai-homebase-incus.conf <<'EOF'
net.ipv4.ip_forward = 1
EOF
sysctl --system >/dev/null

install -d -m 0755 /usr/local/sbin
cat >/usr/local/sbin/ai-homebase-incus-network.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail

bridge_name="${INCUS_BRIDGE_NAME}"
bridge_subnet="${INCUS_BRIDGE_SUBNET}"
default_iface="\$(ip route show default 0.0.0.0/0 | awk '{print \$5; exit}')"

if [[ -z "\${default_iface}" ]]; then
  echo "Unable to determine default network interface for Incus NAT." >&2
  exit 1
fi

sysctl -w net.ipv4.ip_forward=1 >/dev/null
iptables -C FORWARD -i "\${bridge_name}" -j ACCEPT 2>/dev/null || iptables -I FORWARD -i "\${bridge_name}" -j ACCEPT
iptables -C FORWARD -o "\${bridge_name}" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || iptables -I FORWARD -o "\${bridge_name}" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -t nat -C POSTROUTING -s "\${bridge_subnet}" -o "\${default_iface}" -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -s "\${bridge_subnet}" -o "\${default_iface}" -j MASQUERADE
EOF
chmod 0755 /usr/local/sbin/ai-homebase-incus-network.sh

cat >/etc/systemd/system/ai-homebase-incus-network.service <<'EOF'
[Unit]
Description=ai-homebase Incus bridge forwarding and NAT rules
After=network-online.target incus.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/ai-homebase-incus-network.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now incus

if ! incus profile show "${INCUS_PROFILE_NAME}" >/dev/null 2>&1; then
  incus admin init --auto
fi

if ! incus network show "${INCUS_BRIDGE_NAME}" >/dev/null 2>&1; then
  incus network create "${INCUS_BRIDGE_NAME}" \
    ipv4.address="${INCUS_BRIDGE_IPV4}" \
    ipv4.nat=true \
    ipv6.address=none
fi

if ! incus storage show "${INCUS_STORAGE_POOL}" >/dev/null 2>&1; then
  incus storage create "${INCUS_STORAGE_POOL}" "${INCUS_STORAGE_DRIVER}"
fi

if ! incus profile device get "${INCUS_PROFILE_NAME}" root pool >/dev/null 2>&1; then
  incus profile device add "${INCUS_PROFILE_NAME}" root disk path=/ pool="${INCUS_STORAGE_POOL}"
fi

if ! incus profile device get "${INCUS_PROFILE_NAME}" eth0 network >/dev/null 2>&1; then
  incus profile device add "${INCUS_PROFILE_NAME}" eth0 nic network="${INCUS_BRIDGE_NAME}" name=eth0
fi

systemctl enable --now ai-homebase-incus-network.service

install -d -m 0775 -o "${TARGET_UID}" -g "${TARGET_GID}" "${OPENCLAW_SHARED_STATE_DIR}"

usermod -aG incus-admin "${TARGET_USER}"
usermod -aG k3s "${TARGET_USER}" 2>/dev/null || true

echo "Host prerequisite setup complete."
echo "Next steps:"
echo "  1. Log out and back in so ${TARGET_USER} picks up new group membership."
echo "  2. Confirm Docker Engine and git are already installed and usable by ${TARGET_USER}."
echo "  3. Copy bootstrap.example.toml to bootstrap.local.toml and edit hosts, API keys, and secrets."
echo "  4. Run python3 scripts/bootstrap-config.py validate --config bootstrap.local.toml"
echo "  5. Run ./scripts/bootstrap-stack.sh --profile k3s --bootstrap-config bootstrap.local.toml --shared-openclaw-state-source ${OPENCLAW_SHARED_STATE_DIR}"
echo "  Shared OpenClaw state dir: ${OPENCLAW_SHARED_STATE_DIR}"
echo "  Incus bridge: ${INCUS_BRIDGE_NAME} (${INCUS_BRIDGE_IPV4}, NAT subnet ${INCUS_BRIDGE_SUBNET})"
