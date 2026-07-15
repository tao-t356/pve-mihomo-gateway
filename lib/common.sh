#!/usr/bin/env bash
set -Eeuo pipefail

RUNTIME_DIR=${RUNTIME_DIR:-/etc/pve-mihomo-gateway}
DRY_RUN=${DRY_RUN:-0}

log()  { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

require_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || die "请使用 root 运行"; }
require_cmd()  { command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"; }

prompt() {
  local var=$1 label=$2 default=${3-} value
  read -r -p "$label [$default]: " value
  printf -v "$var" '%s' "${value:-$default}"
}

confirm() { local reply; read -r -p "$1 [y/N]: " reply; [[ $reply =~ ^[Yy]$ ]]; }

valid_ipv4() {
  local ip=$1 IFS=. part
  read -r -a parts <<<"$ip"
  [[ ${#parts[@]} -eq 4 ]] || return 1
  for part in "${parts[@]}"; do
    [[ $part =~ ^[0-9]+$ && $part -ge 0 && $part -le 255 ]] || return 1
  done
}

random_hex() { openssl rand -hex "${1:-16}"; }
random_password() { printf 'Agh-%s' "$(openssl rand -hex 6)"; }

run() {
  if [[ $DRY_RUN == 1 ]]; then printf '[dry-run] '; printf '%q ' "$@"; printf '\n';
  else "$@"; fi
}

wait_for() {
  local timeout=$1 description=$2; shift 2
  local end=$((SECONDS + timeout))
  until "$@" >/dev/null 2>&1; do
    (( SECONDS < end )) || die "等待超时: $description"
    sleep 2
  done
}

render_template() {
  local source=$1 target=$2
  if [[ $target == /dev/stdout ]]; then envsubst <"$source"; else envsubst <"$source" >"$target"; fi
}

download_first() {
  local output=$1; shift
  local url
  for url in "$@"; do
    log "下载: $url"
    if curl -fL --connect-timeout 10 --max-time 1800 --retry 2 "$url" -o "$output.part"; then
      mv "$output.part" "$output"
      return 0
    fi
    rm -f "$output.part"
    warn "下载失败，尝试下一个源"
  done
  return 1
}
