#!/usr/bin/env bash
set -euo pipefail

REPO_ARCHIVE_URL="https://github.com/sunset-move/mihomo-menu/archive/refs/heads/main.tar.gz"
MIHOMO_RELEASE_API="https://api.github.com/repos/MetaCubeX/mihomo/releases/latest"
INSTALL_PREFIX="/usr/local/bin"
LIB_PREFIX="/usr/local/lib"
SYSTEMD_DIR="/etc/systemd/system"
MIHOMO_DIR="/etc/mihomo"
TMP_DIR=""
MIHOMO_BIN_PATH=""

cleanup() {
  [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}
trap cleanup EXIT

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "请使用 root 或 sudo 运行安装脚本。" >&2
    exit 1
  fi
}

install_whiptail_best_effort() {
  if command -v whiptail >/dev/null 2>&1; then
    return
  fi

  echo "[info] 检测到系统未安装 whiptail，尝试安装（失败也不影响基本功能）..."

  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update >/dev/null 2>&1 || true
    apt-get install -y whiptail >/dev/null 2>&1 || true
    return
  fi

  if command -v dnf >/dev/null 2>&1; then
    dnf install -y newt >/dev/null 2>&1 || true
    return
  fi

  if command -v yum >/dev/null 2>&1; then
    yum install -y newt >/dev/null 2>&1 || true
    return
  fi

  if command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm libnewt >/dev/null 2>&1 || true
    return
  fi

  if command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive install newt >/dev/null 2>&1 || true
    return
  fi

  if command -v apk >/dev/null 2>&1; then
    apk add --no-cache newt >/dev/null 2>&1 || true
    return
  fi
}

prepare_source_tree() {
  TMP_DIR=$(mktemp -d)
  echo "[1/6] 下载项目文件..."
  curl -fsSL "$REPO_ARCHIVE_URL" | tar -xz -C "$TMP_DIR"
  echo "${TMP_DIR}/mihomo-menu-main"
}

detect_arch() {
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
  arch_tag=$(detect_arch)
  if [[ "$arch_tag" == "unsupported" ]]; then
    echo "不支持的系统架构：$(uname -m)" >&2
    echo "请先手动安装 Mihomo 核心，再执行本安装脚本。" >&2
    exit 1
  fi

  echo "[2/7] 未检测到 Mihomo，开始自动安装核心..."
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
  gunzip -c "$tmp_gz" > /usr/local/bin/mihomo
  chmod 0755 /usr/local/bin/mihomo
  rm -f "$tmp_gz" "$release_json"
  MIHOMO_BIN_PATH="/usr/local/bin/mihomo"
  echo "[2/7] Mihomo 已安装到 ${MIHOMO_BIN_PATH}"
}

ensure_mihomo_core() {
  local existing
  if existing=$(find_existing_mihomo); then
    MIHOMO_BIN_PATH="$existing"
    echo "[2/7] 检测到已有 Mihomo: ${MIHOMO_BIN_PATH}"
    return
  fi

  install_mihomo_core
}

ensure_secret() {
  mkdir -p "$MIHOMO_DIR/subscriptions.d"

  if [[ ! -f "$MIHOMO_DIR/secret.key" ]]; then
    echo "[3/7] 生成 /etc/mihomo/secret.key ..."
    python3 - <<'PY' > "$MIHOMO_DIR/secret.key"
import secrets
print(secrets.token_urlsafe(16))
PY
    chmod 600 "$MIHOMO_DIR/secret.key"
  else
    echo "[3/7] 已存在 /etc/mihomo/secret.key，跳过生成"
  fi
}

install_scripts() {
  local src_root="$1"
  echo "[4/7] 安装脚本到 ${INSTALL_PREFIX} ..."
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

install_systemd_files() {
  local src_root="$1"
  if ! command -v systemctl >/dev/null 2>&1; then
    echo "[5/7] 当前系统没有 systemd，跳过 service/timer 安装"
    return
  fi

  echo "[5/7] 安装 systemd 文件..."
  install -d "$SYSTEMD_DIR"
  install -m 0644 "${src_root}/systemd/mihomo-startup-check.service" "${SYSTEMD_DIR}/mihomo-startup-check.service"
  install -m 0644 "${src_root}/systemd/mihomo-startup-check.timer" "${SYSTEMD_DIR}/mihomo-startup-check.timer"
  systemctl daemon-reload
  systemctl enable --now mihomo-startup-check.timer || true
}

show_summary() {
  echo "[6/7] 尝试安装 whiptail（可选）..."
  install_whiptail_best_effort

  echo "[7/7] 安装完成"
  echo
  echo "Mihomo 核心路径: ${MIHOMO_BIN_PATH}"
  echo "你接下来通常只需要这些命令："
  echo "  mihomo-menu"
  echo "  mihomo-sub-add airport1 '你的订阅链接'"
  echo "  mihomo-sub-use airport1"
  echo "  mihomo-delay --timeout 4000 --select 1"
  echo
  echo "如果你已经有 /etc/mihomo/config.yaml，可以直接开始用。"
  echo "如果还没有配置文件，请先准备基础 Mihomo 配置后再使用订阅/节点管理脚本。"
}

main() {
  require_root
  local src_root
  src_root=$(prepare_source_tree)
  ensure_mihomo_core
  ensure_secret
  install_scripts "$src_root"
  install_systemd_files "$src_root"
  show_summary
}

main "$@"
