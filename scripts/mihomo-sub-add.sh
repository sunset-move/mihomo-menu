#!/usr/bin/env bash
set -euo pipefail

SUB_DIR=/etc/mihomo/subscriptions.d

if [[ $# -lt 2 ]]; then
  echo "Usage: mihomo-sub-add <name> <subscription-url>" >&2
  exit 1
fi

name="$1"
shift
url="$*"

mkdir -p "$SUB_DIR"
printf '%s\n' "$url" > "${SUB_DIR}/${name}.url"
chmod 600 "${SUB_DIR}/${name}.url"

echo "Saved subscription: ${name}"
echo "Path: ${SUB_DIR}/${name}.url"
