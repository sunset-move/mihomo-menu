#!/usr/bin/env python3
import base64
import json
import sys
from pathlib import Path


SKIP_MARKERS = (
    "\u5269\u4f59\u6d41\u91cf",  # 剩余流量
    "\u5957\u9910\u5230\u671f",  # 套餐到期
    "\u8fc7\u6ee4\u6389",        # 过滤掉
)


def q(value: str) -> str:
    return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"') + '"'


def decode_subscription(raw_text: str) -> list[str]:
    raw_text = raw_text.strip()
    if "vmess://" in raw_text:
        return [line.strip() for line in raw_text.splitlines() if line.strip()]

    decoded = base64.b64decode(raw_text).decode("utf-8", "replace")
    return [line.strip() for line in decoded.splitlines() if line.strip()]


def is_clash_yaml(raw_text: str) -> bool:
    text = raw_text.lstrip("\ufeff").strip()
    if not text:
        return False
    return (
        "proxies:" in text
        and ("proxy-groups:" in text or "rules:" in text or "port:" in text or "mixed-port:" in text)
        and "vmess://" not in text
    )


def inject_managed_yaml(raw_text: str) -> str:
    managed_single_keys = {
        "allow-lan",
        "bind-address",
        "external-controller",
        "external-ui",
        "external-ui-url",
        "secret",
    }
    managed_block_keys = {
        "external-controller-cors",
        "profile",
    }

    lines = raw_text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    out: list[str] = []
    skip_block = False

    for line in lines:
        stripped = line.lstrip()
        is_top_level = stripped == line and ":" in line and not line.startswith("#")
        if is_top_level:
            key = line.split(":", 1)[0].strip()
            if key in managed_single_keys or key in managed_block_keys:
                skip_block = key in managed_block_keys
                continue
            skip_block = False
            out.append(line)
            continue

        if skip_block:
            if stripped and stripped == line:
                skip_block = False
                out.append(line)
            else:
                continue
        else:
            out.append(line)

    while out and out[-1] == "":
        out.pop()

    out.extend(
        [
            "allow-lan: false",
            "bind-address: 127.0.0.1",
            "external-controller: 0.0.0.0:9090",
            "external-controller-cors:",
            "  allow-origins:",
            "    - '*'",
            "  allow-private-network: true",
            "external-ui: ui",
            'external-ui-url: "https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"',
            "profile:",
            "  store-selected: true",
            "",
        ]
    )

    return "\n".join(out)


def parse_vmess(uri: str) -> dict:
    body = uri.split("://", 1)[1]
    body += "=" * (-len(body) % 4)
    return json.loads(base64.b64decode(body).decode("utf-8", "replace"))


def build_proxies(lines: list[str]) -> list[dict]:
    proxies: list[dict] = []
    seen_names: dict[str, int] = {}

    for line in lines:
        if not line.startswith("vmess://"):
            continue

        vmess = parse_vmess(line)
        ps = (vmess.get("ps") or "").strip()
        if any(marker in ps for marker in SKIP_MARKERS):
            continue

        base_name = ps or f"node-{len(proxies) + 1}"
        count = seen_names.get(base_name, 0) + 1
        seen_names[base_name] = count
        final_name = base_name if count == 1 else f"{base_name} #{count}"
        final_name = f"{final_name} [{len(proxies) + 1:02d}]"

        node = {
            "name": final_name,
            "type": "vmess",
            "server": vmess["add"],
            "port": int(vmess["port"]),
            "uuid": vmess["id"],
            "alterId": int(vmess.get("aid", 0) or 0),
            "cipher": vmess.get("scy") or "auto",
            "udp": True,
            "network": vmess.get("net") or "ws",
            "path": vmess.get("path") or "/",
            "host": vmess.get("host") or vmess["add"],
        }
        if (vmess.get("tls") or "").lower() in ("tls", "true"):
            node["tls"] = True
        if vmess.get("sni"):
            node["servername"] = vmess["sni"]

        proxies.append(node)

    if not proxies:
        raise SystemExit("No usable vmess nodes found in subscription")

    return proxies


def render_config(proxies: list[dict]) -> str:
    node_names = [proxy["name"] for proxy in proxies]
    lines: list[str] = [
        "mixed-port: 7890",
        "allow-lan: false",
        "bind-address: 127.0.0.1",
        "mode: rule",
        "log-level: info",
        "ipv6: false",
        "unified-delay: true",
        "external-controller: 0.0.0.0:9090",
        "external-controller-cors:",
        "  allow-origins:",
        "    - '*'",
        "  allow-private-network: true",
        "external-ui: ui",
        'external-ui-url: "https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"',
        "profile:",
        "  store-selected: true",
        "",
        "proxies:",
    ]

    for proxy in proxies:
        lines.append(f"  - name: {q(proxy['name'])}")
        lines.append(f"    type: {proxy['type']}")
        lines.append(f"    server: {proxy['server']}")
        lines.append(f"    port: {proxy['port']}")
        lines.append(f"    uuid: {proxy['uuid']}")
        lines.append(f"    alterId: {proxy['alterId']}")
        lines.append(f"    cipher: {proxy['cipher']}")
        lines.append("    udp: true")
        lines.append(f"    network: {proxy['network']}")
        lines.append("    ws-opts:")
        lines.append(f"      path: {q(proxy['path'])}")
        lines.append("      headers:")
        lines.append(f"        Host: {proxy['host']}")
        if proxy.get("tls"):
            lines.append("    tls: true")
        if proxy.get("servername"):
            lines.append(f"    servername: {proxy['servername']}")

    lines += [
        "",
        "proxy-groups:",
        "  - name: AUTO",
        "    type: url-test",
        "    url: http://www.gstatic.com/generate_204",
        "    interval: 300",
        "    tolerance: 50",
        "    proxies:",
    ]
    for name in node_names:
        lines.append(f"      - {q(name)}")

    lines += [
        "  - name: PROXY",
        "    type: select",
        "    proxies:",
        "      - AUTO",
        "      - DIRECT",
    ]
    for name in node_names:
        lines.append(f"      - {q(name)}")

    lines += [
        "",
        "rules:",
        "  - IP-CIDR,127.0.0.0/8,DIRECT,no-resolve",
        "  - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve",
        "  - IP-CIDR,172.16.0.0/12,DIRECT,no-resolve",
        "  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve",
        "  - IP-CIDR,100.64.0.0/10,DIRECT,no-resolve",
        "  - IP-CIDR,169.254.0.0/16,DIRECT,no-resolve",
        "  - IP-CIDR,224.0.0.0/4,DIRECT,no-resolve",
        "  - DOMAIN,localhost,DIRECT",
        "  - DOMAIN-SUFFIX,local,DIRECT",
        "  - MATCH,PROXY",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: mihomo-sub2config.py <subscription-file>")

    raw_text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
    if is_clash_yaml(raw_text):
        sys.stdout.write(inject_managed_yaml(raw_text))
        return
    lines = decode_subscription(raw_text)
    proxies = build_proxies(lines)
    sys.stdout.write(render_config(proxies))


if __name__ == "__main__":
    main()
