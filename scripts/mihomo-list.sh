#!/usr/bin/env bash
set -euo pipefail

SECRET=$(tr -d '\r\n' < /etc/mihomo/secret.key)
GROUP_NAME=$(/usr/local/bin/mihomo-main-group)

curl -fsS -H "Authorization: Bearer ${SECRET}" http://127.0.0.1:9090/proxies \
  | python3 -c 'import json,sys; group_name=sys.argv[1]; data=json.load(sys.stdin); group=data["proxies"][group_name]; all_names=group.get("all", []); print("Group:", group_name); print("Current:", group.get("now","")); print(""); print("Built-ins:"); [print(" -", name) for name in all_names if name in ("AUTO","DIRECT")]; print(""); print("Nodes:"); nodes=[name for name in all_names if name not in ("AUTO","DIRECT")]; [print(f"{i:02d}. {name}") for i, name in enumerate(nodes, 1)]' "$GROUP_NAME"
