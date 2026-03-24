#!/usr/bin/env bash
set -euo pipefail

exec "$(cd "$(dirname "$0")" && pwd)/bootstrap-stack.sh" --profile k3s "$@"
