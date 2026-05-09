# mihomo-menu v0.2.0

`mihomo-menu` is a Linux / SSH / headless-environment management toolkit for Mihomo.

The main goal of `v0.2.0` is to move the project from “a set of helper scripts” toward “a more complete one-click bootstrap base”.

## Highlights

- The installer now detects whether Mihomo already exists on the target system
- If Mihomo is missing, it installs the official Mihomo core automatically
- If Mihomo already exists, it tries to reuse the existing binary and current config
- A default `mihomo.service` template is now included
- Subscription can be passed during installation via environment variables
- Existing `config.yaml` is backed up before patching
- If no `config.yaml` exists, the installer can generate one from a subscription or create a minimal starter config
- Added English README
- Added `CHANGELOG.md`

## Who This Release Is For

This release is especially useful for:

- users who already have Mihomo on a server and want to add a management layer cleanly
- users who do not yet have Mihomo and want a quick bootstrap path
- Linux users who mainly manage Mihomo over SSH

## One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/sunset-move/mihomo-menu/main/install.sh | sudo bash
```

To inject a subscription during installation:

```bash
curl -fsSL https://raw.githubusercontent.com/sunset-move/mihomo-menu/main/install.sh | \
sudo env MIHOMO_SUBSCRIPTION_NAME=airport1 MIHOMO_SUBSCRIPTION_URL='your subscription URL' bash
```

## Core Capabilities

- `mihomo-menu`
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
- latency testing and ranking-based switching:
  - `mihomo-delay`
- proxy connectivity test:
  - `mihomo-test`
- WebUI update:
  - `mihomo-ui-update`
- current subscription update:
  - `mihomo-update`
- startup health check:
  - `mihomo-startup-check.service`
  - `mihomo-startup-check.timer`

## Scope and Boundaries

`v0.2.0` now supports:

- detecting an existing Mihomo installation
- installing Mihomo automatically if missing
- creating a usable base runtime environment

But it is still **not** a tool that automatically designs a perfect production rule set for every user.

More precisely:

- it deploys and wires the management layer
- it tries to integrate with existing environments
- it can generate config from an existing subscription
- it does not attempt to invent a universal final routing strategy for every provider and every use case

## Version Tag

- Tag: `v0.2.0`
