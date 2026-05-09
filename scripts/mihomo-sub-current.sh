#!/usr/bin/env bash
set -euo pipefail

CURRENT_NAME_FILE=/etc/mihomo/current_subscription_name
ACTIVE_FILE=/etc/mihomo/subscription.url

echo "Current subscription name:"
if [[ -f "$CURRENT_NAME_FILE" ]]; then
  cat "$CURRENT_NAME_FILE"
else
  echo "(unknown)"
fi

echo
echo "Current active subscription URL:"
if [[ -f "$ACTIVE_FILE" ]]; then
  cat "$ACTIVE_FILE"
else
  echo "(missing)"
fi
