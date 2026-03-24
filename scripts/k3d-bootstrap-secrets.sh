#!/usr/bin/env bash
set -Eeuo pipefail

exec "$(dirname "$0")/bootstrap-secrets.sh" --profile k3d "$@"
