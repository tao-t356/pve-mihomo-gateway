#!/usr/bin/env bash
set -Eeuo pipefail

: "${AGH_ADMIN_PASSWORD:?}"
: "${MIHOMO_IP:?}"
: "${AGH_DISABLE_IPV6:=false}"
: "${AGH_VERSION:=0.107.78}"
: "${APT_MIRROR:=https://mirrors.ustc.edu.cn/debian}"
: "${GITHUB_PROXY:=https://ghfast.top/}"
: "${GITHUB_PROXY_ALT:=https://gh-proxy.com/}"

download_first() {
  local output=$1; shift
  local url
  for url in "$@"; do
    echo "download: $url"
    if curl -fL --connect-timeout 10 --max-time 600 --retry 2 "$url" -o "$output.part"; then
      mv "$output.part" "$output"
      return 0
    fi
    rm -f "$output.part"
  done
  return 1
}

if [[ -f /etc/apt/sources.list.d/debian.sources ]]; then
  sed -i \
    -e "s#https\?://deb.debian.org/debian#${APT_MIRROR}#g" \
    -e "s#https\?://security.debian.org/debian-security#${APT_MIRROR}-security#g" \
    /etc/apt/sources.list.d/debian.sources
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl tar dnsutils

cd /tmp
AGH_GITHUB_URL="https://github.com/AdguardTeam/AdGuardHome/releases/download/v${AGH_VERSION}/AdGuardHome_linux_amd64.tar.gz"
download_first AdGuardHome.tar.gz \
  https://static.adtidy.org/adguardhome/release/AdGuardHome_linux_amd64.tar.gz \
  "${GITHUB_PROXY}${AGH_GITHUB_URL}" \
  "${GITHUB_PROXY_ALT}${AGH_GITHUB_URL}" \
  "$AGH_GITHUB_URL"
tar -xzf AdGuardHome.tar.gz
install -d -m 700 /opt/AdGuardHome
cp -a AdGuardHome/. /opt/AdGuardHome/
/opt/AdGuardHome/AdGuardHome -s install || true
sed -i 's#^WorkingDirectory=/tmp#WorkingDirectory=/opt/AdGuardHome#' /etc/systemd/system/AdGuardHome.service
systemctl daemon-reload
systemctl reset-failed tmp.mount AdGuardHome.service || true
systemctl enable --now AdGuardHome

for _ in $(seq 1 30); do curl -fsS http://127.0.0.1:3000/control/install/get_addresses >/dev/null 2>&1 && break; sleep 1; done

curl -fsS -X POST -H 'Content-Type: application/json' \
  -d "{\"web\":{\"ip\":\"0.0.0.0\",\"port\":3000},\"dns\":{\"ip\":\"0.0.0.0\",\"port\":53,\"autofix\":true},\"username\":\"admin\",\"password\":\"${AGH_ADMIN_PASSWORD}\"}" \
  http://127.0.0.1:3000/control/install/configure

sleep 5
curl -fsS -u "admin:${AGH_ADMIN_PASSWORD}" -X POST -H 'Content-Type: application/json' \
  -d "{\"upstream_dns\":[\"${MIHOMO_IP}:1053\"],\"upstream_dns_file\":\"\",\"bootstrap_dns\":[\"223.5.5.5\",\"119.29.29.29\"],\"fallback_dns\":[\"223.5.5.5\",\"119.29.29.29\"],\"protection_enabled\":true,\"ratelimit\":0,\"blocking_mode\":\"default\",\"edns_cs_enabled\":false,\"dnssec_enabled\":false,\"disable_ipv6\":${AGH_DISABLE_IPV6},\"upstream_mode\":\"\",\"cache_size\":16777216,\"cache_ttl_min\":0,\"cache_ttl_max\":0,\"cache_optimistic\":true,\"resolve_clients\":true,\"use_private_ptr_resolvers\":true}" \
  http://127.0.0.1:3000/control/dns_config

curl --max-time 60 -fsS -u "admin:${AGH_ADMIN_PASSWORD}" -X POST -H 'Content-Type: application/json' \
  -d '{"name":"anti-AD","url":"https://anti-ad.net/easylist.txt","whitelist":false}' \
  http://127.0.0.1:3000/control/filtering/add_url || true
curl --max-time 60 -fsS -u "admin:${AGH_ADMIN_PASSWORD}" -X POST -H 'Content-Type: application/json' \
  -d '{"whitelist":false}' http://127.0.0.1:3000/control/filtering/refresh || true

timedatectl set-timezone Asia/Shanghai
apt-get clean
rm -rf /tmp/AdGuardHome /tmp/AdGuardHome.tar.gz
