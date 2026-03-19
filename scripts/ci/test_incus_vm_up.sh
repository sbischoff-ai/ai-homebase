#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

fakebin="${tmp_dir}/fakebin"
state_dir="${tmp_dir}/state"
incus_log="${tmp_dir}/incus.log"
mkdir -p "${fakebin}" "${state_dir}"

cat > "${fakebin}/incus" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >> "${incus_log}"

if [[ "\${1:-}" == "info" ]]; then
  exit 1
fi

if [[ "\${1:-}" == "network" && "\${2:-}" == "show" ]]; then
  exit 1
fi

if [[ "\${1:-}" == "init" ]]; then
  echo "incus init should not run when the bridge is missing" >&2
  exit 99
fi

exit 0
EOF
chmod +x "${fakebin}/incus"

set +e
output="$(
  PATH="${fakebin}:${PATH}" \
  BOOTSTRAP_LOG_FILE="${tmp_dir}/bootstrap.log" \
  "${REPO_ROOT}/scripts/incus-vm-up.sh" \
    --vm-name test-incus-vm \
    --network missingbr0 \
    --state-dir "${state_dir}" \
    --ssh-key-path "${state_dir}/id_ed25519" \
    2>&1
)"
status=$?
set -e

if [[ ${status} -eq 0 ]]; then
  echo "Expected scripts/incus-vm-up.sh to fail for a missing Incus network." >&2
  exit 1
fi

for expected in \
  "Requested Incus network 'missingbr0' was not found." \
  "defaults to the 'incusbr0' bridge" \
  "Initialize Incus so it creates a bridge" \
  "scripts/incus-vm-up.sh --network <name>"; do
  if [[ "${output}" != *"${expected}"* ]]; then
    echo "Missing expected error text: ${expected}" >&2
    echo "--- script output ---" >&2
    echo "${output}" >&2
    exit 1
  fi
done

if grep -q '^init ' "${incus_log}"; then
  echo "incus init was invoked despite the missing network preflight." >&2
  cat "${incus_log}" >&2
  exit 1
fi

echo "incus-vm-up missing-network preflight behaves as expected."
