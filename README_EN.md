# mihomo-menu

[中文 README](./README.md) | [English README](./README_EN.md)

`mihomo-menu` is a CLI-oriented management toolkit for Mihomo on Linux servers.

This project exists for a very practical reason:

- many servers only have SSH and no desktop environment
- `metacubexd` / WebUI is great for switching nodes inside the **current subscription**
- but switching **multiple subscription sources**, testing latency, selecting the fastest node, and running startup health checks are still awkward from plain shell

So this project fills that gap.

## Features

- interactive menu: `mihomo-menu`
- multi-subscription management:
  - `mihomo-sub-add`
  - `mihomo-sub-list`
  - `mihomo-sub-current`
  - `mihomo-sub-use`
- node management:
  - `mihomo-list`
  - `mihomo-current`
  - `mihomo-select`
  - `mihomo-select-index`
- latency testing:
  - `mihomo-delay`
  - supports switching directly to the Nth fastest node
- proxy connectivity test:
  - `mihomo-test`
- WebUI update:
  - `mihomo-ui-update`
- current subscription update:
  - `mihomo-update`
- startup health check:
  - `mihomo-startup-check.sh`
  - `mihomo-startup-check.timer`

## Use Cases

- Ubuntu / Debian / CentOS / Rocky / AlmaLinux / Fedora / Arch / Alpine
- Mihomo managed over SSH
- servers without GUI
- users who want to keep WebUI for node switching, but still want CLI for subscription switching and automation

## One-Line Install

Run this on the target machine:

```bash
curl -fsSL https://raw.githubusercontent.com/sunset-move/mihomo-menu/main/install.sh | sudo bash
```

The installer will:

1. download the repository archive
2. install scripts into `/usr/local/bin/`
3. install systemd files into `/etc/systemd/system/`
4. create:
   - `/etc/mihomo/subscriptions.d`
   - `/etc/mihomo/secret.key` if missing
5. try to install `whiptail` for a better TUI experience
6. enable the startup health-check timer

## Requirements

This project does **not** install the Mihomo core itself. It is a management layer.

Expected environment:

- Mihomo binary installed
  - recommended path: `/usr/local/bin/mihomo`
- Mihomo config directory:
  - `/etc/mihomo/`
- current active subscription file:
  - `/etc/mihomo/subscription.url`
- Mihomo controller API available
  - common examples:
    - `127.0.0.1:9090`
    - `0.0.0.0:9090`

## Project Structure

```text
scripts/
  mihomo-menu.sh
  mihomo-main-group.py
  mihomo-list.sh
  mihomo-current.sh
  mihomo-select.sh
  mihomo-select-index.sh
  mihomo-delay.py
  mihomo-test.sh
  mihomo-sub-add.sh
  mihomo-sub-list.sh
  mihomo-sub-current.sh
  mihomo-sub-use.sh
  mihomo-sub2config.py
  mihomo-update.sh
  mihomo-ui-update.sh
  mihomo-startup-check.sh

systemd/
  mihomo-startup-check.service
  mihomo-startup-check.timer
```

## Quick Start

### 1. Add your first subscription

```bash
mihomo-sub-add airport1 'your subscription URL'
```

### 2. Switch to it

```bash
mihomo-sub-use airport1
```

### 3. Open the interactive menu

```bash
mihomo-menu
```

### 4. Test latency manually

```bash
mihomo-delay --timeout 4000
```

### 5. Switch to the fastest node

```bash
mihomo-delay --timeout 4000 --select 1
```

## WebUI vs This Project

`metacubexd` / WebUI is good for:

- viewing the current node
- switching nodes inside the current subscription
- checking connections
- reading logs
- monitoring traffic

But it is **not ideal for switching between multiple subscription sources**.

Why?

Because switching subscriptions is not only about selecting another node. It usually means:

1. replacing the current subscription source
2. regenerating `config.yaml`
3. restarting Mihomo

So the intended split is:

- node-level operations: WebUI
- subscription-source switching: `mihomo-menu` / `mihomo-sub-use`

## Supported Subscription Formats

Current scripts support:

1. raw `base64 + vmess://...` subscriptions
2. full `Clash YAML` subscriptions

It does **not** guarantee support for every possible future format, especially mixed or newer schemes such as:

- `vless://`
- `trojan://`
- `hysteria://`
- `tuic://`

If needed, extend `mihomo-sub2config.py`.

## Menu Modes

`mihomo-menu` supports two interaction modes:

1. if `whiptail` is available
   - it uses a dialog-style TUI
   - less flicker
   - supports arrow keys

2. if terminal capability is poor
   - it falls back to a plain numeric menu
   - still usable in minimal environments

For node selection:

- arrow key selection is supported
- recent latency is shown
- `Esc` exits the dialog

## Startup Health Check

After installation, the timer is enabled:

- `mihomo-startup-check.timer`

Log file:

```text
/var/log/mihomo-startup-check.log
```

Run it manually:

```bash
sudo systemctl start mihomo-startup-check.service
```

Read logs:

```bash
tail -n 50 /var/log/mihomo-startup-check.log
```

## Common Commands

```bash
mihomo-menu
mihomo-sub-list
mihomo-sub-current
mihomo-sub-use airport1
mihomo-list
mihomo-current
mihomo-delay --timeout 4000
mihomo-delay --timeout 4000 --select 1
mihomo-test
mihomo-update
mihomo-ui-update
```

## Security Notes

- do not commit real subscription URLs into a public repository
- do not commit `/etc/mihomo/secret.key`
- do not publish generated full node configs publicly

## License

MIT
