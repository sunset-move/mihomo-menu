#!/usr/bin/env python3
import json
import urllib.request
from pathlib import Path


SECRET = Path("/etc/mihomo/secret.key").read_text(encoding="utf-8", errors="replace").strip()
REQ = urllib.request.Request(
    "http://127.0.0.1:9090/proxies",
    headers={"Authorization": f"Bearer {SECRET}"},
)


def main() -> None:
    with urllib.request.urlopen(REQ, timeout=15) as response:
        data = json.load(response)

    proxies = data["proxies"]
    priority_names = ["PROXY", "🔰 选择节点", "GLOBAL"]
    for name in priority_names:
        item = proxies.get(name)
        if isinstance(item, dict) and isinstance(item.get("all"), list):
            print(name)
            return

    priority_types = {"Selector", "URLTest", "Fallback", "LoadBalance", "selector", "urltest", "fallback", "loadbalance"}
    for name, item in proxies.items():
        if not isinstance(item, dict):
            continue
        if item.get("type") in priority_types and isinstance(item.get("all"), list):
            print(name)
            return

    raise SystemExit("No selectable proxy group found")


if __name__ == "__main__":
    main()
