#!/usr/bin/env bash
set -euo pipefail

default_timeout=4000
MENU_CHOICE=""

MENU_LABELS=(
  "查看常用信息（WebUI / 密钥 / 当前订阅 / 当前节点）"
  "查看当前订阅"
  "列出已保存订阅"
  "切换订阅"
  "新增订阅"
  "查看当前节点"
  "列出当前节点组（原始顺序）"
  "测速所有节点（只看排名）"
  "测速并切到最快节点"
  "按测速排名切节点"
  "按原始列表选择节点"
  "测试当前代理是否可用"
  "更新当前订阅"
  "更新 WebUI"
  "查看服务状态"
)

tty_available() {
  tty -s 2>/dev/null
}

supports_terminal_ui() {
  tty_available && [[ -n "${TERM:-}" ]] && [[ "${TERM:-}" != "dumb" ]] && [[ "${TERM:-}" != "unknown" ]]
}

use_whiptail() {
  supports_terminal_ui && command -v whiptail >/dev/null 2>&1
}

pause() {
  printf '\n按回车继续...'
  read -r _
}

safe_clear() {
  if supports_terminal_ui; then
    clear
  else
    printf '\n'
  fi
}

read_default() {
  local prompt="$1"
  local default_value="$2"
  local result
  read -r -p "$prompt [$default_value]: " result
  if [[ -z "$result" ]]; then
    printf '%s' "$default_value"
  else
    printf '%s' "$result"
  fi
}

prompt_value() {
  local prompt="$1"
  local default_value="${2:-}"
  local result=""

  if use_whiptail; then
    result=$(whiptail --inputbox "$prompt" 10 80 "$default_value" 3>&1 1>&2 2>&3) || return 1
    printf '%s' "$result"
    return 0
  fi

  result=$(read_default "$prompt" "$default_value")
  printf '%s' "$result"
}

get_current_sub_name() {
  if [[ -f /etc/mihomo/current_subscription_name ]]; then
    tr -d '\r\n' < /etc/mihomo/current_subscription_name
  else
    echo "(unknown)"
  fi
}

get_current_node() {
  /usr/local/bin/mihomo-current 2>/dev/null || echo "(unknown)"
}

get_secret() {
  cat /etc/mihomo/secret.key 2>/dev/null || echo "(missing)"
}

detect_ipv4s() {
  python3 - <<'PY'
import socket

ips = []
for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
    ip = info[4][0]
    if ip.startswith("127."):
        continue
    if ip not in ips:
        ips.append(ip)

for ip in ips:
    print(ip)
PY
}

detect_tailscale_ipv4() {
  if command -v tailscale >/dev/null 2>&1; then
    tailscale ip -4 2>/dev/null | head -n 1 || true
  fi
}

show_header() {
  local current_sub current_node
  current_sub=$(get_current_sub_name)
  current_node=$(get_current_node)
  echo
  echo "================ Mihomo 菜单 ================"
  echo "当前订阅: $current_sub"
  echo "当前节点: $current_node"
  echo "---------------------------------------------"
  echo "============================================="
}

show_info() {
  local secret current_sub current_node tailscale_ip
  secret=$(get_secret)
  current_sub=$(get_current_sub_name)
  current_node=$(get_current_node)
  tailscale_ip=$(detect_tailscale_ipv4)

  echo
  echo "WebUI 示例地址："
  echo "  - 本机: http://127.0.0.1:9090/ui/"
  while IFS= read -r ip; do
    [[ -n "$ip" ]] && echo "  - 局域网: http://${ip}:9090/ui/"
  done < <(detect_ipv4s)
  [[ -n "$tailscale_ip" ]] && echo "  - Tailscale: http://${tailscale_ip}:9090/ui/"
  echo
  echo "WebUI 密钥: $secret"
  echo "当前订阅: $current_sub"
  echo "当前节点: $current_node"
}

switch_subscription() {
  local name="$1"
  /usr/local/bin/mihomo-sub-use "$name"
  echo
  echo "当前节点:"
  /usr/local/bin/mihomo-current || true
}

choose_subscription_interactive() {
  local current_sub sub_dir selected
  current_sub=$(get_current_sub_name)
  sub_dir=/etc/mihomo/subscriptions.d

  if [[ ! -d "$sub_dir" ]]; then
    echo "未找到订阅目录: $sub_dir"
    return 1
  fi

  if use_whiptail; then
    local args=""
    while IFS= read -r file; do
      local name desc
      name=$(basename "$file" .url)
      desc="saved subscription"
      if [[ "$name" == "$current_sub" ]]; then
        desc="* current"
      fi
      args="$args $(python3 -c 'import shlex,sys; print(shlex.quote(sys.argv[1]), shlex.quote(sys.argv[2]))' "$name" "$desc")"
    done < <(find "$sub_dir" -maxdepth 1 -type f -name '*.url' | sort)

    [[ -z "$args" ]] && return 1
    local cmd
    cmd="whiptail --clear --title '切换订阅' --menu '选择要切换的订阅' 20 90 10 ${args} 3>&1 1>&2 2>&3"
    selected=$(eval "$cmd") || return 1
  else
    echo
    /usr/local/bin/mihomo-sub-list
    echo
    selected=$(prompt_value "输入要切换的订阅名" "") || return 1
  fi

  [[ -n "$selected" ]] || return 1
  switch_subscription "$selected"
}

choose_node_interactive() {
  local current_node group_name secret json_file
  current_node=$(/usr/local/bin/mihomo-current 2>/dev/null || true)
  group_name=$(/usr/local/bin/mihomo-main-group)
  secret=$(get_secret)
  json_file=$(mktemp)

  curl -fsS -H "Authorization: Bearer ${secret}" http://127.0.0.1:9090/proxies > "$json_file"

  if use_whiptail; then
    local menu_args selected_index
    menu_args=$(python3 - "$json_file" "$group_name" "$current_node" <<'PY'
import json
import shlex
import sys

json_path, group_name, current_node = sys.argv[1], sys.argv[2], sys.argv[3]
data = json.load(open(json_path, 'r', encoding='utf-8'))
group = data["proxies"][group_name]
nodes = [name for name in group.get("all", []) if name not in ("AUTO", "DIRECT")]
parts = []

for idx, name in enumerate(nodes, 1):
    tag = f"{idx:02d}"
    item = data["proxies"].get(name, {})
    history = item.get("history") or []
    delay = "N/A"
    if history:
      last = history[-1].get("delay")
      if isinstance(last, int):
        delay = f"{last}ms"
    prefix = "*" if name == current_node else " "
    display = f"{prefix} {delay:<6} {name}"
    parts.append(shlex.quote(tag))
    parts.append(shlex.quote(display))

print(" ".join(parts))
PY
    )

    local cmd
    cmd="whiptail --clear --title '按原始列表选择节点' --menu '当前组: ${group_name} (含最近延迟)' 25 120 16 ${menu_args} 3>&1 1>&2 2>&3"
    selected_index=$(eval "$cmd") || {
      rm -f "$json_file"
      return 1
    }

    rm -f "$json_file"
    /usr/local/bin/mihomo-select-index "$selected_index"
    return 0
  fi

  echo
  /usr/local/bin/mihomo-list
  echo
  local raw_index
  raw_index=$(prompt_value "按原始节点列表编号切换（输入编号）" "1") || {
    rm -f "$json_file"
    return 1
  }
  rm -f "$json_file"
  /usr/local/bin/mihomo-select-index "$raw_index"
}

draw_menu() {
  local selected="$1"
  local number_buffer="$2"
  safe_clear
  show_header
  echo "操作方式："
  echo "  - 上下键选择，回车执行"
  echo "  - 也可以直接输入数字后回车"
  echo "  - 按 Esc 或输入 0 退出"
  echo "---------------------------------------------"
  local idx=1
  for label in "${MENU_LABELS[@]}"; do
    if [[ "$idx" -eq "$selected" ]]; then
      printf ' > %2d) %s\n' "$idx" "$label"
    else
      printf '   %2d) %s\n' "$idx" "$label"
    fi
    idx=$((idx + 1))
  done
  printf '   %2d) %s\n' 0 "退出"
  if [[ -n "$number_buffer" ]]; then
    echo "---------------------------------------------"
    echo "当前数字输入: $number_buffer"
  fi
}

choose_main_menu_whiptail() {
  local current_sub current_node title choice
  current_sub=$(get_current_sub_name)
  current_node=$(get_current_node)
  title="当前订阅: ${current_sub} | 当前节点: ${current_node}"

  choice=$(
    whiptail \
      --clear \
      --backtitle "$title" \
      --title "mihomo-menu" \
      --menu "选择功能" \
      24 100 15 \
      "1"  "查看常用信息（WebUI / 密钥 / 当前订阅 / 当前节点）" \
      "2"  "查看当前订阅" \
      "3"  "列出已保存订阅" \
      "4"  "切换订阅" \
      "5"  "新增订阅" \
      "6"  "查看当前节点" \
      "7"  "列出当前节点组（原始顺序）" \
      "8"  "测速所有节点（只看排名）" \
      "9"  "测速并切到最快节点" \
      "10" "按测速排名切节点" \
      "11" "按原始列表选择节点" \
      "12" "测试当前代理是否可用" \
      "13" "更新当前订阅" \
      "14" "更新 WebUI" \
      "15" "查看服务状态" \
      "0"  "退出" \
      3>&1 1>&2 2>&3
  ) || {
    MENU_CHOICE="0"
    return
  }

  MENU_CHOICE="$choice"
}

choose_main_menu() {
  MENU_CHOICE=""

  if use_whiptail; then
    choose_main_menu_whiptail
    return
  fi

  show_header
  local idx=1
  for label in "${MENU_LABELS[@]}"; do
    printf ' %2d) %s\n' "$idx" "$label"
    idx=$((idx + 1))
  done
  printf ' %2d) %s\n' 0 "退出"
  read -r -p "请选择: " MENU_CHOICE
}

while true; do
  choose_main_menu
  safe_clear

  if [[ "$MENU_CHOICE" =~ ^[0-9]+$ ]] && [[ "$MENU_CHOICE" -ge 1 ]] && [[ "$MENU_CHOICE" -le "${#MENU_LABELS[@]}" ]]; then
    echo "正在执行: ${MENU_LABELS[$((MENU_CHOICE - 1))]}"
    echo "---------------------------------------------"
  fi

  case "$MENU_CHOICE" in
    1)
      show_info
      pause
      ;;
    2)
      /usr/local/bin/mihomo-sub-current
      pause
      ;;
    3)
      /usr/local/bin/mihomo-sub-list
      pause
      ;;
    4)
      choose_subscription_interactive || true
      pause
      ;;
    5)
      local_sub_name=$(prompt_value "输入新订阅名称（例如 airport3）" "") || {
        pause
        continue
      }
      local_sub_url=$(prompt_value "输入新订阅链接" "") || {
        pause
        continue
      }
      if [[ -n "$local_sub_name" && -n "$local_sub_url" ]]; then
        /usr/local/bin/mihomo-sub-add "$local_sub_name" "$local_sub_url"
      fi
      pause
      ;;
    6)
      /usr/local/bin/mihomo-current
      pause
      ;;
    7)
      /usr/local/bin/mihomo-list
      pause
      ;;
    8)
      timeout_value=$(prompt_value "测速超时毫秒" "$default_timeout") || {
        pause
        continue
      }
      /usr/local/bin/mihomo-delay --timeout "$timeout_value"
      pause
      ;;
    9)
      timeout_value=$(prompt_value "测速超时毫秒" "$default_timeout") || {
        pause
        continue
      }
      /usr/local/bin/mihomo-delay --timeout "$timeout_value" --select 1
      echo
      echo "切换后当前节点:"
      /usr/local/bin/mihomo-current || true
      pause
      ;;
    10)
      timeout_value=$(prompt_value "测速超时毫秒" "$default_timeout") || {
        pause
        continue
      }
      rank_value=$(prompt_value "按测速结果排名切换（输入名次）" "1") || {
        pause
        continue
      }
      /usr/local/bin/mihomo-delay --timeout "$timeout_value" --select "$rank_value"
      echo
      echo "切换后当前节点:"
      /usr/local/bin/mihomo-current || true
      pause
      ;;
    11)
      choose_node_interactive || true
      echo
      echo "切换后当前节点:"
      /usr/local/bin/mihomo-current || true
      pause
      ;;
    12)
      /usr/local/bin/mihomo-test
      pause
      ;;
    13)
      /usr/local/bin/mihomo-update
      pause
      ;;
    14)
      /usr/local/bin/mihomo-ui-update
      pause
      ;;
    15)
      systemctl is-enabled mihomo 2>/dev/null || true
      echo "---"
      systemctl is-active mihomo 2>/dev/null || true
      echo "---"
      systemctl --no-pager --full status mihomo | sed -n '1,25p'
      pause
      ;;
    0)
      exit 0
      ;;
    *)
      echo "无效选择，请重新输入。"
      pause
      ;;
  esac
done
