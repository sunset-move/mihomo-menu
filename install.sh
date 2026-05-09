#!/usr/bin/env bash
set -euo pipefail

REPO_ARCHIVE_URL="https://github.com/sunset-move/mihomo-menu/archive/refs/heads/main.tar.gz"
INSTALL_PREFIX="/usr/local/bin"
LIB_PREFIX="/usr/local/lib"
SYSTEMD_DIR="/etc/systemd/system"
MIHOMO_DIR="/etc/mihomo"
TMP_DIR=""

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

ensure_secret() {
  mkdir -p "$MIHOMO_DIR/subscriptions.d"

  if [[ ! -f "$MIHOMO_DIR/secret.key" ]]; then
    echo "[2/6] 生成 /etc/mihomo/secret.key ..."
    python3 - <<'PY' > "$MIHOMO_DIR/secret.key"
import secrets
print(secrets.token_urlsafe(16))
PY
    chmod 600 "$MIHOMO_DIR/secret.key"
  else
    echo "[2/6] 已存在 /etc/mihomo/secret.key，跳过生成"
  fi
}

install_scripts() {
  local src_root="$1"
  echo "[3/6] 安装脚本到 ${INSTALL_PREFIX} ..."
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
    echo "[4/6] 当前系统没有 systemd，跳过 service/timer 安装"
    return
  fi

  echo "[4/6] 安装 systemd 文件..."
  install -d "$SYSTEMD_DIR"
  install -m 0644 "${src_root}/systemd/mihomo-startup-check.service" "${SYSTEMD_DIR}/mihomo-startup-check.service"
  install -m 0644 "${src_root}/systemd/mihomo-startup-check.timer" "${SYSTEMD_DIR}/mihomo-startup-check.timer"
  systemctl daemon-reload
  systemctl enable --now mihomo-startup-check.timer || true
}

show_summary() {
  echo "[5/6] 尝试安装 whiptail（可选）..."
  install_whiptail_best_effort

  echo "[6/6] 安装完成"
  echo
  echo "你接下来通常只需要这些命令："
  echo "  mihomo-menu"
  echo "  mihomo-sub-add airport1 '你的订阅链接'"
  echo "  mihomo-sub-use airport1"
  echo "  mihomo-delay --timeout 4000 --select 1"
  echo
  echo "如果你已经有 Mihomo 核心和 /etc/mihomo/config.yaml，可以直接开始用。"
  echo "如果没有，请先安装 Mihomo 本体，再使用这套管理脚本。"
}

main() {
  require_root
  local src_root
  src_root=$(prepare_source_tree)
  ensure_secret
  install_scripts "$src_root"
  install_systemd_files "$src_root"
  show_summary
}

main "$@"
