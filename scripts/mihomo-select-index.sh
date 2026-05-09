#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: mihomo-select-index <number>" >&2
  exit 1
fi

INDEX="$1"
SECRET=$(tr -d '\r\n' < /etc/mihomo/secret.key)
GROUP_NAME=$(/usr/local/bin/mihomo-main-group)

TARGET=$(curl -fsS -H "Authorization: Bearer ${SECRET}" http://127.0.0.1:9090/proxies \
  | python3 -c 'import json,sys; index=int(sys.argv[1]); group_name=sys.argv[2]; data=json.load(sys.stdin); choices=[name for name in data["proxies"][group_name].get("all", []) if name not in ("AUTO","DIRECT")]; print(choices[index - 1]) if 1 <= index <= len(choices) else (_ for _ in ()).throw(SystemExit(f"Index out of range: 1-{len(choices)}"))' "$INDEX" "$GROUP_NAME"
)

/usr/local/bin/mihomo-select "$TARGET"
