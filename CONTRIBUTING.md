# Contributing

Thanks for contributing to `mihomo-menu`.

This project is focused on a practical goal:

- making Mihomo easier to manage on Linux servers
- especially over SSH
- especially when there is no desktop environment

## Before You Start

Please keep these constraints in mind:

1. This repository is public.
   - Never commit real subscription URLs.
   - Never commit `/etc/mihomo/secret.key`.
   - Never commit generated full node configs with private credentials.

2. This project should stay compatible with mainstream Linux distributions.
   - Prefer POSIX-friendly shell patterns when reasonable.
   - Do not assume only one distro family.
   - Treat `whiptail` as optional, not mandatory.

3. This project should work in SSH / headless environments.
   - Always consider poor terminal capability.
   - Prefer graceful fallback behavior over fancy-only UI.

## Development Principles

When sending changes, prefer:

- small, focused commits
- minimal hard-coded environment assumptions
- preserving existing user configuration when possible
- explicit logging and failure messages
- safe defaults

## Local Checks

Before opening a PR, at minimum run:

```bash
bash -n ./install.sh
for f in ./scripts/*.sh; do bash -n "$f"; done
for f in ./scripts/*.py; do python3 -m py_compile "$f"; done
```

Also verify:

- line endings stay as LF for shell/systemd files
- no accidental `__pycache__` or binary junk is committed
- README / CHANGELOG are updated if behavior changes

## Typical Contribution Areas

Useful contributions include:

- improving installer compatibility across distros
- supporting more subscription input formats
- improving terminal interaction and fallback behavior
- improving startup diagnostics
- reducing assumptions about existing Mihomo layouts
- improving docs in Chinese and English

## Pull Request Notes

Please include:

1. what problem you are solving
2. what files were changed
3. how you tested it
4. any compatibility or migration impact

## Release Notes

If your change affects users directly, also update:

- `CHANGELOG.md`

If it is a release-oriented change, it is helpful to also update:

- `RELEASE_NOTES_vX.Y.Z_zh.md`
- `RELEASE_NOTES_vX.Y.Z_en.md`

## Security

If you notice a security-sensitive issue:

- do not publish real credentials in issues
- describe the problem generically
- provide redacted examples only
