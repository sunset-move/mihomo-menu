#!/usr/bin/env bash
set -euo pipefail

SECRET=$(tr -d '\r\n' < /etc/mihomo/secret.key)
GROUP_NAME=$(/usr/local/bin/mihomo-main-group)
GROUP_PATH=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$GROUP_NAME")

curl -fsS -H "Authorization: Bearer ${SECRET}" "http://127.0.0.1:9090/proxies/${GROUP_PATH}" \
  | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("now",""))'
