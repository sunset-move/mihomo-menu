#!/usr/bin/env bash
set -euo pipefail

SUB_DIR=/etc/mihomo/subscriptions.d
CURRENT_NAME_FILE=/etc/mihomo/current_subscription_name

current_name=""
if [[ -f "$CURRENT_NAME_FILE" ]]; then
  current_name=$(tr -d '\r\n' < "$CURRENT_NAME_FILE")
fi

echo "Saved subscriptions:"

if [[ ! -d "$SUB_DIR" ]]; then
  echo "  (none)"
  exit 0
fi

shopt -s nullglob
for file in "$SUB_DIR"/*.url; do
  name=$(basename "$file" .url)
  mark=" "
  [[ "$name" == "$current_name" ]] && mark="*"
  echo " $mark $name"
done

echo
echo "* means current active subscription"
