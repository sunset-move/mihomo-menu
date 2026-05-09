#!/usr/bin/env python3
import argparse
import json
import sys
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path


CONTROLLER = "http://127.0.0.1:9090"
SECRET_FILE = Path("/etc/mihomo/secret.key")


def auth_headers() -> dict:
    secret = SECRET_FILE.read_text(encoding="utf-8", errors="replace").strip()
    return {"Authorization": f"Bearer {secret}"}


def api_get(path: str) -> dict:
    request = urllib.request.Request(f"{CONTROLLER}{path}", headers=auth_headers())
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.load(response)


def measure(name: str, test_url: str, timeout_ms: int) -> tuple[str, int | None, str | None]:
    encoded = urllib.parse.quote(name, safe="")
    query = urllib.parse.urlencode({"url": test_url, "timeout": timeout_ms})
    request_url = f"{CONTROLLER}/proxies/{encoded}/delay?{query}"
    try:
        request = urllib.request.Request(request_url, headers=auth_headers())
        with urllib.request.urlopen(request, timeout=max(10, timeout_ms / 1000 + 5)) as response:
            data = json.load(response)
        delay = data.get("delay")
        return name, delay if isinstance(delay, int) and delay > 0 else None, None
    except Exception as exc:
        return name, None, str(exc)


def main() -> int:
    parser = argparse.ArgumentParser(description="Measure delay for all Mihomo nodes in PROXY group")
    parser.add_argument("--url", default="https://www.gstatic.com/generate_204", help="URL used for delay test")
    parser.add_argument("--timeout", type=int, default=5000, help="Delay timeout in milliseconds")
    parser.add_argument("--workers", type=int, default=8, help="Concurrent worker count")
    parser.add_argument("--select", type=int, help="Switch to the Nth fastest node after testing")
    args = parser.parse_args()

    proxies = api_get("/proxies")
    proxy_map = proxies["proxies"]

    priority_names = ["PROXY", "🔰 选择节点", "GLOBAL"]
    group_name = None
    for name in priority_names:
        item = proxy_map.get(name)
        if isinstance(item, dict) and isinstance(item.get("all"), list):
            group_name = name
            break

    if group_name is None:
        priority_types = {"Selector", "URLTest", "Fallback", "LoadBalance", "selector", "urltest", "fallback", "loadbalance"}
        for name, item in proxy_map.items():
            if isinstance(item, dict) and item.get("type") in priority_types and isinstance(item.get("all"), list):
                group_name = name
                break

    if group_name is None:
        raise SystemExit("No selectable proxy group found")

    group = proxy_map[group_name]
    current = group.get("now", "")
    all_names = group.get("all", [])
    node_names = [name for name in all_names if name not in ("AUTO", "DIRECT")]

    results = []
    with ThreadPoolExecutor(max_workers=max(1, args.workers)) as pool:
        futures = {pool.submit(measure, name, args.url, args.timeout): name for name in node_names}
        for future in as_completed(futures):
            results.append(future.result())

    def sort_key(item: tuple[str, int | None, str | None]) -> tuple[int, int, str]:
        name, delay, _ = item
        return (0 if delay is not None else 1, delay if delay is not None else 10**9, name)

    results.sort(key=sort_key)

    print(f"Group: {group_name}")
    print(f"Current: {current}")
    print(f"Test URL: {args.url}")
    print(f"Timeout: {args.timeout} ms")
    print("")
    print(f"{'No.':>3}  {'Delay':>7}  {'Current':>7}  Name")
    print("-" * 72)

    for index, (name, delay, error) in enumerate(results, 1):
        delay_text = f"{delay} ms" if delay is not None else "fail"
        current_mark = "*" if name == current else ""
        if error and delay is None:
            print(f"{index:>3}  {delay_text:>7}  {current_mark:>7}  {name}  [{error}]")
        else:
            print(f"{index:>3}  {delay_text:>7}  {current_mark:>7}  {name}")

    if args.select is not None:
        selectable = [(name, delay) for name, delay, error in results if delay is not None]
        if args.select < 1 or args.select > len(selectable):
            raise SystemExit(f"--select out of range: 1-{len(selectable)}")
        target_name = selectable[args.select - 1][0]
        encoded_group = urllib.parse.quote(group_name, safe="")
        payload = json.dumps({"name": target_name}, ensure_ascii=False).encode("utf-8")
        request = urllib.request.Request(
            f"{CONTROLLER}/proxies/{encoded_group}",
            data=payload,
            headers={**auth_headers(), "Content-Type": "application/json"},
            method="PUT",
        )
        with urllib.request.urlopen(request, timeout=15):
            pass
        print("")
        print(f"Switched {group_name} to: {target_name}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
