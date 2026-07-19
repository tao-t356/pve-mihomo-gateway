#!/usr/bin/env bash
set -Eeuo pipefail

: "${MIHOMO_CONFIG_B64:?}"
: "${MIHOMO_SECRET:?}"
: "${SUBSTORE_BACKEND_PATH:?}"
: "${MIHOMO_IP:?}"
: "${ROS_IPV6_LINK_LOCAL:=}"
: "${WAN_INTERFACE:=}"
: "${MIHOMO_VERSION:=1.19.28}"
: "${ZASHBOARD_VERSION:=3.15.0}"
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
apt-get install -y ca-certificates curl jq unzip docker.io nftables qemu-guest-agent dnsutils
systemctl enable --now docker qemu-guest-agent

if [[ -z $WAN_INTERFACE ]]; then
  WAN_INTERFACE=$(ip -4 route show default | awk '{print $5; exit}')
fi
[[ -n $WAN_INTERFACE && -e /sys/class/net/$WAN_INTERFACE ]] || {
  echo "cannot detect WAN interface: $WAN_INTERFACE" >&2
  exit 1
}

install -d -m 755 /etc/mihomo/ui /opt/sub-store

MIHOMO_URL="https://github.com/MetaCubeX/mihomo/releases/download/v${MIHOMO_VERSION}/mihomo-linux-amd64-v3-v${MIHOMO_VERSION}.gz"
download_first /tmp/mihomo.gz "${GITHUB_PROXY}${MIHOMO_URL}" "${GITHUB_PROXY_ALT}${MIHOMO_URL}" "$MIHOMO_URL"
gzip -dc /tmp/mihomo.gz > /usr/local/bin/mihomo
chmod 755 /usr/local/bin/mihomo
rm -f /tmp/mihomo.gz

ZASHBOARD_URL="https://github.com/Zephyruso/zashboard/releases/download/v${ZASHBOARD_VERSION}/dist.zip"
download_first /tmp/zashboard.zip "${GITHUB_PROXY}${ZASHBOARD_URL}" "${GITHUB_PROXY_ALT}${ZASHBOARD_URL}" "$ZASHBOARD_URL"
unzip -q -o /tmp/zashboard.zip -d /etc/mihomo/ui
rm -f /tmp/zashboard.zip

printf '%s' "$MIHOMO_CONFIG_B64" | base64 -d > /etc/mihomo/config.yaml

cat > /etc/systemd/system/mihomo.service <<'EOF'
[Unit]
Description=Mihomo Proxy Core
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/mihomo -d /etc/mihomo
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/mihomo/dns-hijack.nft <<EOF
table inet mihomo_dns_hijack {
  chain prerouting {
    type nat hook prerouting priority -110; policy accept;
    iifname "${WAN_INTERFACE}" meta l4proto { tcp, udp } th dport 53 redirect to :1053
  }
}
EOF

cat > /etc/systemd/system/mihomo-dns-hijack.service <<'EOF'
[Unit]
Description=Redirect LAN DNS to Mihomo
After=network-online.target mihomo.service
Wants=network-online.target mihomo.service

[Service]
Type=oneshot
ExecStartPre=-/usr/sbin/nft delete table inet mihomo_dns_hijack
ExecStart=/usr/sbin/nft -f /etc/mihomo/dns-hijack.nft
ExecStop=-/usr/sbin/nft delete table inet mihomo_dns_hijack
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/sysctl.d/99-mihomo-router.conf <<'EOF'
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
net.ipv6.conf.${WAN_INTERFACE}.accept_ra=2
net.ipv6.conf.all.disable_ipv6=0
EOF
sysctl --system >/dev/null

if [[ -n $ROS_IPV6_LINK_LOCAL ]]; then
cat > /etc/systemd/system/mihomo-ipv6-route.service <<EOF
[Unit]
Description=Persistent IPv6 default route for Mihomo host
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ip -6 route replace default via ${ROS_IPV6_LINK_LOCAL} dev ${WAN_INTERFACE} metric 100
ExecStop=-/usr/sbin/ip -6 route del default via ${ROS_IPV6_LINK_LOCAL} dev ${WAN_INTERFACE} metric 100
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
fi

/usr/local/bin/mihomo -t -d /etc/mihomo
systemctl daemon-reload
if [[ -n $ROS_IPV6_LINK_LOCAL ]]; then systemctl enable --now mihomo-ipv6-route.service; fi
systemctl enable --now mihomo
systemctl enable --now mihomo-dns-hijack.service

SUBSTORE_IMAGE=''
for image in \
  ghcr.nju.edu.cn/xream/sub-store:latest \
  ghcr.io/xream/sub-store:latest; do
  if timeout 180 docker pull "$image"; then SUBSTORE_IMAGE=$image; break; fi
done
[[ -n $SUBSTORE_IMAGE ]] || { echo "Sub-Store 镜像下载失败" >&2; exit 1; }
docker rm -f sub-store >/dev/null 2>&1 || true
docker run -d --name sub-store --restart unless-stopped \
  -p 3001:3001 \
  -e "SUB_STORE_FRONTEND_BACKEND_PATH=/${SUBSTORE_BACKEND_PATH}" \
  -e "SUB_STORE_CORS_ALLOWED_ORIGINS=http://${MIHOMO_IP}:3001" \
  -v /opt/sub-store:/opt/app/data \
  "$SUBSTORE_IMAGE"

apt-get clean
fstrim -av || true
