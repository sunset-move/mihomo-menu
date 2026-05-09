#!/usr/bin/env bash
set -euo pipefail

REPO_ARCHIVE_URL="https://github.com/sunset-move/mihomo-menu/archive/refs/heads/main.tar.gz"
MIHOMO_RELEASE_API="https://api.github.com/repos/MetaCubeX/mihomo/releases/latest"
INSTALL_PREFIX="/usr/local/bin"
LIB_PREFIX="/usr/local/lib"
SYSTEMD_DIR="/etc/systemd/system"
MIHOMO_DIR="/etc/mihomo"
MIHOMO_STATE_DIR="/var/lib/mihomo"
MIHOMO_USER="mihomo"
MIHOMO_BIN_LINK="/usr/local/bin/mihomo"
TMP_DIR=""

cleanup() {
  [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}
trap cleanup EXIT

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Please run this installer as root or via sudo." >&2
    exit 1
  fi
}

install_optional_package() {
  local package="$1"

  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update >/dev/null 2>&1 || true
    apt-get install -y "$package" >/dev/null 2>&1 || true
    return
  fi

  if command -v dnf >/dev/null 2>&1; then
    dnf install -y "$package" >/dev/null 2>&1 || true
    return
  fi

  if command -v yum >/dev/null 2>&1; then
    yum install -y "$package" >/dev/null 2>&1 || true
    return
  fi

  if command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm "$package" >/dev/null 2>&1 || true
    return
  fi

  if command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive install "$package" >/dev/null 2>&1 || true
    return
  fi

  if command -v apk >/dev/null 2>&1; then
    apk add --no-cache "$package" >/dev/null 2>&1 || true
    return
  fi
}

ensure_basic_dependencies() {
  if ! command -v python3 >/dev/null 2>&1; then
    echo "[0/9] python3 not found, trying to install it..."
    install_optional_package python3
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required but could not be installed automatically." >&2
    exit 1
  fi

  if ! command -v base64 >/dev/null 2>&1; then
    echo "base64 command is required. Please install coreutils first." >&2
    exit 1
  fi

  if ! command -v gunzip >/dev/null 2>&1; then
    echo "gunzip is required. Please install gzip first." >&2
    exit 1
  fi
}

prepare_source_tree() {
  TMP_DIR=$(mktemp -d)
  echo "[1/9] Downloading project archive..."
  curl -fsSL "$REPO_ARCHIVE_URL" | tar -xz -C "$TMP_DIR"
  echo "${TMP_DIR}/mihomo-menu-main"
}

detect_arch_tag() {
  local arch
  arch=$(uname -m)
  case "$arch" in
    x86_64|amd64)
      echo "linux-amd64"
      ;;
    aarch64|arm64)
      echo "linux-arm64"
      ;;
    armv7l|armv7)
      echo "linux-armv7"
      ;;
    armv6l|armv6)
      echo "linux-armv6"
      ;;
    *)
      echo "unsupported"
      ;;
  esac
}

find_existing_mihomo() {
  if command -v mihomo >/dev/null 2>&1; then
    command -v mihomo
    return 0
  fi

  local candidate
  for candidate in /usr/local/bin/mihomo /usr/bin/mihomo /opt/mihomo/mihomo; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

install_mihomo_core() {
  local arch_tag release_json asset_url tmp_gz
  arch_tag=$(detect_arch_tag)

  if [[ "$arch_tag" == "unsupported" ]]; then
    echo "Unsupported architecture: $(uname -m)" >&2
    echo "Please install Mihomo manually, then rerun this installer." >&2
    exit 1
  fi

  echo "[2/9] Mihomo core not found, installing the official release..."
  release_json=$(mktemp)
  curl -fsSL -H "User-Agent: mihomo-menu-installer" "$MIHOMO_RELEASE_API" -o "$release_json"

  asset_url=$(python3 - "$release_json" "$arch_tag" <<'PY'
import json
import sys

release_path, arch_tag = sys.argv[1], sys.argv[2]
data = json.load(open(release_path, 'r', encoding='utf-8'))
target = None

for asset in data.get("assets", []):
    name = asset.get("name", "")
    if arch_tag in name and name.endswith(".gz"):
        if "-compatible" in name:
            continue
        target = asset.get("browser_download_url")
        break

if not target:
    raise SystemExit("No suitable Mihomo release asset found")

print(target)
PY
  )

  tmp_gz=$(mktemp)
  curl -fsSL "$asset_url" -o "$tmp_gz"
  gunzip -c "$tmp_gz" > "$MIHOMO_BIN_LINK"
  chmod 0755 "$MIHOMO_BIN_LINK"
  rm -f "$tmp_gz" "$release_json"
}

ensure_mihomo_core() {
  local existing_path
  if existing_path=$(find_existing_mihomo); then
    echo "[2/9] Detected existing Mihomo binary: ${existing_path}"
    if [[ "$existing_path" != "$MIHOMO_BIN_LINK" ]]; then
      ln -sf "$existing_path" "$MIHOMO_BIN_LINK"
      echo "[2/9] Created compatibility link: ${MIHOMO_BIN_LINK} -> ${existing_path}"
    fi
    return
  fi

  install_mihomo_core
}

ensure_mihomo_user() {
  if id "$MIHOMO_USER" >/dev/null 2>&1; then
    return
  fi

  echo "[3/9] Creating system user: ${MIHOMO_USER}"
  if command -v useradd >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin "$MIHOMO_USER"
    return
  fi

  if command -v adduser >/dev/null 2>&1; then
    adduser -S -H -s /sbin/nologin "$MIHOMO_USER" >/dev/null 2>&1 || adduser -S "$MIHOMO_USER" >/dev/null 2>&1 || true
    return
  fi

  echo "Unable to auto-create the mihomo user. Please create it manually." >&2
  exit 1
}

ensure_directories() {
  install -d -m 0755 "$MIHOMO_DIR"
  install -d -m 0700 "$MIHOMO_DIR/subscriptions.d"
  install -d -o "$MIHOMO_USER" -g "$MIHOMO_USER" -m 0755 "$MIHOMO_STATE_DIR"
}

ensure_secret() {
  if [[ ! -f "$MIHOMO_DIR/secret.key" ]]; then
    echo "[4/9] Creating /etc/mihomo/secret.key ..."
    python3 - <<'PY' > "$MIHOMO_DIR/secret.key"
import secrets
print(secrets.token_urlsafe(16))
PY
    chmod 600 "$MIHOMO_DIR/secret.key"
  else
    echo "[4/9] Reusing existing /etc/mihomo/secret.key"
  fi
}

install_scripts() {
  local src_root="$1"
  echo "[5/9] Installing management scripts..."
  install -d "$INSTALL_PREFIX"
  install -d "$LIB_PREFIX"

  install -m 0755 "${src_root}/scripts/mihomo-current.sh" "${INSTALL_PREFIX}/mihomo-current"
  install -m 0755 "${src_root}/scripts/mihomo-delay.py" "${INSTALL_PREFIX}/mihomo-delay"
  install -m 0755 "${src_root}/scripts/mihomo-list.sh" "${INSTALL_PREFIX}/mihomo-list"
  install -m 0755 "${src_root}/scripts/mihomo-main-group.py" "${INSTALL_PREFIX}/mihomo-main-group"
  install -m 0755 "${src_root}/scripts/mihomo-menu.sh" "${INSTALL_PREFIX}/mihomo-menu"
  install -m 0755 "${src_root}/scripts/mihomo-select-index.sh" "${INSTALL_PREFIX}/mihomo-select-index"
  install -m 0755 "${src_root}/scripts/mihomo-select.sh" "${INSTALL_PREFIX}/mihomo-select"
  install -m 0755 "${src_root}/scripts/mihomo-startup-check.sh" "${INSTALL_PREFIX}/mihomo-startup-check.sh"
  install -m 0755 "${src_root}/scripts/mihomo-sub-add.sh" "${INSTALL_PREFIX}/mihomo-sub-add"
  install -m 0755 "${src_root}/scripts/mihomo-sub-current.sh" "${INSTALL_PREFIX}/mihomo-sub-current"
  install -m 0755 "${src_root}/scripts/mihomo-sub-list.sh" "${INSTALL_PREFIX}/mihomo-sub-list"
  install -m 0755 "${src_root}/scripts/mihomo-sub-use.sh" "${INSTALL_PREFIX}/mihomo-sub-use"
  install -m 0755 "${src_root}/scripts/mihomo-sub2config.py" "${LIB_PREFIX}/mihomo-sub2config.py"
  install -m 0755 "${src_root}/scripts/mihomo-test.sh" "${INSTALL_PREFIX}/mihomo-test"
  install -m 0755 "${src_root}/scripts/mihomo-ui-update.sh" "${INSTALL_PREFIX}/mihomo-ui-update"
  install -m 0755 "${src_root}/scripts/mihomo-update.sh" "${INSTALL_PREFIX}/mihomo-update"
}

ensure_mihomo_service() {
  local src_root="$1"

  if ! command -v systemctl >/dev/null 2>&1; then
    echo "[6/9] systemd not found, skipping service/timer installation"
    return
  fi

  if [[ ! -f "${SYSTEMD_DIR}/mihomo.service" ]]; then
    echo "[6/9] Installing default mihomo.service ..."
    install -m 0644 "${src_root}/systemd/mihomo.service" "${SYSTEMD_DIR}/mihomo.service"
  else
    echo "[6/9] Existing mihomo.service detected, keeping current service"
  fi

  install -m 0644 "${src_root}/systemd/mihomo-startup-check.service" "${SYSTEMD_DIR}/mihomo-startup-check.service"
  install -m 0644 "${src_root}/systemd/mihomo-startup-check.timer" "${SYSTEMD_DIR}/mihomo-startup-check.timer"
  systemctl daemon-reload
}

save_subscription_if_provided() {
  local name="${MIHOMO_SUBSCRIPTION_NAME:-default}"
  local url="${MIHOMO_SUBSCRIPTION_URL:-}"

  if [[ -z "$url" ]]; then
    return
  fi

  echo "[7/9] Subscription URL provided via environment, saving as ${name} ..."
  printf '%s\n' "$url" > "${MIHOMO_DIR}/subscriptions.d/${name}.url"
  chmod 600 "${MIHOMO_DIR}/subscriptions.d/${name}.url"
  printf '%s\n' "$name" > "${MIHOMO_DIR}/current_subscription_name"
  chmod 600 "${MIHOMO_DIR}/current_subscription_name"
  install -o root -g root -m 600 "${MIHOMO_DIR}/subscriptions.d/${name}.url" "${MIHOMO_DIR}/subscription.url"
}

create_minimal_config() {
  local secret
  secret=$(tr -d '\r\n' < "${MIHOMO_DIR}/secret.key")

  cat > "${MIHOMO_DIR}/config.yaml" <<EOF
port: 7890
socks-port: 7891
allow-lan: false
bind-address: 127.0.0.1
mode: Rule
log-level: info
ipv6: false
external-controller: 0.0.0.0:9090
external-controller-cors:
  allow-origins:
    - '*'
  allow-private-network: true
external-ui: ui
external-ui-url: "https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"
profile:
  store-selected: true
proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - DIRECT
rules:
  - MATCH,DIRECT
secret: "${secret}"
EOF

  chown root:"${MIHOMO_USER}" "${MIHOMO_DIR}/config.yaml"
  chmod 0640 "${MIHOMO_DIR}/config.yaml"
}

patch_existing_config() {
  local secret backup
  secret=$(tr -d '\r\n' < "${MIHOMO_DIR}/secret.key")
  backup="${MIHOMO_DIR}/config.yaml.bak.$(date +%Y%m%d-%H%M%S)"
  cp "${MIHOMO_DIR}/config.yaml" "$backup"
  echo "[7/9] Existing config.yaml detected, backup created: ${backup}"

  python3 - "${MIHOMO_DIR}/config.yaml" "$secret" <<'PY'
import importlib.util
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
secret = sys.argv[2]
spec = importlib.util.spec_from_file_location("mihomo_sub2config", "/usr/local/lib/mihomo-sub2config.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

text = config_path.read_text(encoding="utf-8", errors="replace")
patched = module.inject_managed_yaml(text)
patched = patched.rstrip("\n") + f'\nsecret: "{secret}"\n'
config_path.write_text(patched, encoding="utf-8", newline="\n")
PY

  chown root:"${MIHOMO_USER}" "${MIHOMO_DIR}/config.yaml"
  chmod 0640 "${MIHOMO_DIR}/config.yaml"
}

generate_config_from_subscription() {
  if [[ ! -s "${MIHOMO_DIR}/subscription.url" ]]; then
    return 1
  fi

  echo "[7/9] Generating config.yaml from the active subscription ..."
  "${INSTALL_PREFIX}/mihomo-update" >/dev/null
  return 0
}

ensure_config() {
  save_subscription_if_provided

  if [[ -f "${MIHOMO_DIR}/config.yaml" ]]; then
    patch_existing_config
    return
  fi

  if generate_config_from_subscription; then
    return
  fi

  echo "[7/9] No existing config or active subscription found, creating a minimal starter config ..."
  create_minimal_config
}

enable_services() {
  if ! command -v systemctl >/dev/null 2>&1; then
    return
  fi

  systemctl enable --now mihomo || true
  systemctl enable --now mihomo-startup-check.timer || true
}

install_whiptail_best_effort() {
  if command -v whiptail >/dev/null 2>&1; then
    return
  fi

  echo "[8/9] whiptail not found, trying to install it (best effort)..."
  install_optional_package whiptail || true
  if ! command -v whiptail >/dev/null 2>&1; then
    install_optional_package newt || true
    install_optional_package libnewt || true
  fi
}

best_effort_ui_update() {
  if [[ -f "${MIHOMO_DIR}/config.yaml" ]] && command -v systemctl >/dev/null 2>&1; then
    "${INSTALL_PREFIX}/mihomo-ui-update" >/dev/null 2>&1 || true
  fi
}

show_summary() {
  echo "[9/9] Installation complete."
  echo
  echo "You can now use:"
  echo "  mihomo-menu"
  echo "  mihomo-sub-add airport1 'your subscription URL'"
  echo "  mihomo-sub-use airport1"
  echo "  mihomo-delay --timeout 4000 --select 1"
  echo
  echo "Optional environment variables for unattended deployment:"
  echo "  MIHOMO_SUBSCRIPTION_URL"
  echo "  MIHOMO_SUBSCRIPTION_NAME"
}

main() {
  require_root
  ensure_basic_dependencies

  local src_root
  src_root=$(prepare_source_tree)
  ensure_mihomo_core
  ensure_mihomo_user
  ensure_directories
  ensure_secret
  install_scripts "$src_root"
  ensure_mihomo_service "$src_root"
  ensure_config
  enable_services
  install_whiptail_best_effort
  best_effort_ui_update
  show_summary
}

main "$@"
