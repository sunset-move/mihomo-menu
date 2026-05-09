#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: mihomo-select <proxy-name>" >&2
  exit 1
fi

SECRET=$(tr -d '\r\n' < /etc/mihomo/secret.key)
GROUP_NAME=$(/usr/local/bin/mihomo-main-group)
GROUP_PATH=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$GROUP_NAME")
TARGET="$*"
JSON_PAYLOAD=$(python3 - "$TARGET" <<'PY'
import json
import sys
print(json.dumps({"name": sys.argv[1]}, ensure_ascii=False))
PY
)

curl -fsS -X PUT \
  -H "Authorization: Bearer ${SECRET}" \
  -H 'Content-Type: application/json' \
  --data "$JSON_PAYLOAD" \
  "http://127.0.0.1:9090/proxies/${GROUP_PATH}" >/dev/null

echo "Switched ${GROUP_NAME} to: $TARGET"
