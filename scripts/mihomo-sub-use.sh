#!/usr/bin/env bash
set -euo pipefail

SUB_DIR=/etc/mihomo/subscriptions.d
ACTIVE_FILE=/etc/mihomo/subscription.url
CURRENT_NAME_FILE=/etc/mihomo/current_subscription_name

if [[ $# -ne 1 ]]; then
  echo "Usage: mihomo-sub-use <name>" >&2
  exit 1
fi

name="$1"
src="${SUB_DIR}/${name}.url"

if [[ ! -f "$src" ]]; then
  echo "Subscription not found: $src" >&2
  exit 1
fi

install -o root -g root -m 600 "$src" "$ACTIVE_FILE"
printf '%s\n' "$name" > "$CURRENT_NAME_FILE"
chmod 600 "$CURRENT_NAME_FILE"

echo "Switched active subscription to: $name"
/usr/local/bin/mihomo-update
