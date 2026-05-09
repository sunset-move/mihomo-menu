#!/usr/bin/env bash
set -euo pipefail

SUB_URL_FILE=/etc/mihomo/subscription.url
SECRET_FILE=/etc/mihomo/secret.key
Mihomo_BIN=/usr/local/bin/mihomo
GENERATOR=/usr/local/lib/mihomo-sub2config.py
CONFIG_DIR=/etc/mihomo
CONFIG_FILE=${CONFIG_DIR}/config.yaml

if [[ ! -f "$SUB_URL_FILE" ]]; then
  echo "Subscription URL file not found: $SUB_URL_FILE" >&2
  exit 1
fi

if [[ ! -x "$Mihomo_BIN" ]]; then
  echo "mihomo binary not found: $Mihomo_BIN" >&2
  exit 1
fi

if [[ ! -f "$GENERATOR" ]]; then
  echo "Generator script not found: $GENERATOR" >&2
  exit 1
fi

if [[ ! -f "$SECRET_FILE" ]]; then
  echo "Secret file not found: $SECRET_FILE" >&2
  exit 1
fi

TMP_DIR=$(mktemp -d)
RAW_SUB=${TMP_DIR}/subscription.txt
NEW_CONFIG=${TMP_DIR}/config.yaml
trap 'rm -rf "$TMP_DIR"' EXIT

SUB_URL=$(<"$SUB_URL_FILE")
SECRET_VALUE=$(tr -d '\r\n' < "$SECRET_FILE")

echo "[1/4] Fetch subscription"
if ! curl -fsSL --max-time 30 "$SUB_URL" -o "$RAW_SUB"; then
  echo "Direct fetch failed, retrying through current local proxy"
  curl -fsSL --proxy http://127.0.0.1:7890 --max-time 60 "$SUB_URL" -o "$RAW_SUB"
fi

echo "[2/4] Generate mihomo config"
python3 "$GENERATOR" "$RAW_SUB" > "$NEW_CONFIG"
printf '\nsecret: "%s"\n' "$SECRET_VALUE" >> "$NEW_CONFIG"

echo "[3/4] Validate config"
"$Mihomo_BIN" -t -f "$NEW_CONFIG" >/dev/null

echo "[4/4] Install config and restart service"
install -o root -g mihomo -m 0640 "$NEW_CONFIG" "$CONFIG_FILE"
systemctl restart mihomo
systemctl --no-pager --full status mihomo
