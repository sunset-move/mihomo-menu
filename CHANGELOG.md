# Changelog

All notable changes to this project will be documented in this file.

## [v0.1.0] - 2026-05-09

### Added

- Initial open-source release of `mihomo-menu`
- Interactive TUI menu for Mihomo management
- Multi-subscription management commands:
  - `mihomo-sub-add`
  - `mihomo-sub-list`
  - `mihomo-sub-current`
  - `mihomo-sub-use`
- Node management commands:
  - `mihomo-list`
  - `mihomo-current`
  - `mihomo-select`
  - `mihomo-select-index`
- Node latency test with direct switching:
  - `mihomo-delay`
- Proxy connectivity test:
  - `mihomo-test`
- WebUI updater:
  - `mihomo-ui-update`
- Current subscription updater:
  - `mihomo-update`
- Startup health check:
  - `mihomo-startup-check.sh`
  - `mihomo-startup-check.service`
  - `mihomo-startup-check.timer`
- One-line installer:
  - `install.sh`
- Chinese README
- English README

### Notes

- Designed primarily for Linux / SSH / no-GUI environments
- WebUI is intended for node switching inside the current subscription
- CLI is intended for subscription-source switching, testing, and maintenance
