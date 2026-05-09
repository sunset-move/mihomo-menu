#!/usr/bin/env bash
set -u

LOG_FILE="/var/log/mihomo-startup-check.log"
CONFIG_FILE="/etc/mihomo/config.yaml"
FAILURES=0

SERVICES=(
  "mihomo"
)

ensure_log_file() {
  if [[ ! -f "$LOG_FILE" ]]; then
    install -o root -g root -m 0640 /dev/null "$LOG_FILE"
  fi
}

log_line() {
  local message="$1"
  printf '[%s] %s\n' "$(date '+%F %T %z')" "$message" >> "$LOG_FILE"
}

get_cfg_value() {
  local key="$1"
  sed -n -E "s/^${key}:[[:space:]]*//p" "$CONFIG_FILE" | head -n 1
}

check_service() {
  local service="$1"
  local enabled active
  enabled=$(systemctl is-enabled "$service" 2>/dev/null || true)
  active=$(systemctl is-active "$service" 2>/dev/null || true)

  if [[ "$enabled" == "enabled" && "$active" == "active" ]]; then
    log_line "OK service=${service} enabled=${enabled} active=${active}"
    return
  fi

  FAILURES=$((FAILURES + 1))
  log_line "FAIL service=${service} enabled=${enabled} active=${active}"
  while IFS= read -r line; do
    log_line "  ${line}"
  done < <(systemctl --no-pager --full status "$service" 2>&1 | sed -n '1,25p')
}

check_port() {
  local port="$1"
  local label="$2"

  if [[ -z "$port" ]]; then
    return
  fi

  if ss -tlnH "( sport = :${port} )" | grep -q .; then
    log_line "OK listener=${label} port=${port}"
  else
    FAILURES=$((FAILURES + 1))
    log_line "FAIL listener=${label} port=${port} not listening"
  fi
}

main() {
  ensure_log_file
  log_line "========== startup check begin =========="

  local service
  for service in "${SERVICES[@]}"; do
    check_service "$service"
  done

  if [[ -f "$CONFIG_FILE" ]]; then
    local mixed_port http_port socks_port controller_value controller_port
    mixed_port=$(get_cfg_value "mixed-port")
    http_port=$(get_cfg_value "port")
    socks_port=$(get_cfg_value "socks-port")
    controller_value=$(get_cfg_value "external-controller")
    controller_port="${controller_value##*:}"

    check_port "$mixed_port" "mihomo-mixed-port"
    check_port "$http_port" "mihomo-http-port"
    check_port "$socks_port" "mihomo-socks-port"
    check_port "$controller_port" "mihomo-controller"
  else
    FAILURES=$((FAILURES + 1))
    log_line "FAIL config file missing: ${CONFIG_FILE}"
  fi

  if [[ "$FAILURES" -eq 0 ]]; then
    log_line "RESULT ok mihomo service and listeners are healthy"
    log_line "========== startup check end =========="
    exit 0
  fi

  log_line "RESULT fail count=${FAILURES}"
  log_line "========== startup check end =========="
  exit 1
}

main "$@"
