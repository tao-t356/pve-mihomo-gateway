#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

require_root
for cmd in qm pct pvesm pveam curl jq openssl envsubst ssh scp ssh-keygen base64 dig; do require_cmd "$cmd"; done
mkdir -p "$RUNTIME_DIR" "$RUNTIME_DIR/state"
chmod 700 "$RUNTIME_DIR"

log "PVE Mihomo Gateway Wizard"
prompt LAN_CIDR "LAN CIDR" "192.168.1.0/24"
prompt ROS_IP "RouterOS IPv4" "192.168.1.2"
prompt ROS_IPV6_LINK_LOCAL "RouterOS LAN link-local IPv6 (blank=auto detect, IPv6 optional)" ""
prompt ENABLE_CLIENT_IPV6 "是否给手机/电脑启用国内 IPv6直连 (yes/no)" "yes"
prompt PVE_BRIDGE "PVE LAN bridge" "vmbr0"
prompt PVE_STORAGE "VM/LXC storage" "local-lvm"
prompt PVE_FILE_STORAGE "Template/cloud image storage" "local"
prompt DOWNLOAD_PROFILE "Download profile (china/official)" "china"
prompt APT_MIRROR "Debian mirror" "https://mirrors.ustc.edu.cn/debian"
prompt GITHUB_PROXY "GitHub proxy prefix" "https://ghfast.top/"
prompt GITHUB_PROXY_ALT "GitHub backup proxy prefix" "https://gh-proxy.com/"
prompt MIHOMO_VERSION "Mihomo version" "1.19.28"
prompt ZASHBOARD_VERSION "Zashboard version" "3.15.0"
prompt AGH_VERSION "AdGuard Home version" "0.107.78"

prompt MIHOMO_VMID "Mihomo VMID" "104"
prompt MIHOMO_IP "Mihomo IPv4" "192.168.1.10"
prompt MIHOMO_DISK_GB "Mihomo disk GiB" "5"
prompt MIHOMO_CORES "Mihomo shared cores" "4"
prompt MIHOMO_MEMORY_MB "Mihomo memory MiB" "2048"

prompt AGH_CTID "AdGuard Home CTID" "105"
prompt AGH_IP "AdGuard Home IPv4" "192.168.1.8"
prompt AGH_DISK_GB "AdGuard Home disk GiB" "3"
prompt AGH_CORES "AdGuard Home shared cores" "4"
prompt AGH_MEMORY_MB "AdGuard Home memory MiB" "512"
prompt MIHOMO_VM_PASSWORD "Mihomo VM password" "facker668"
prompt MIHOMO_EXTRA_RULES_FILE "Mihomo extra rules file (blank=none)" "$ROOT_DIR/templates/mihomo.extra-rules.yaml"

prompt SUBSTORE_SUB_NAME "Sub-Store subscription name" "mmw"
prompt ROS_LAN_INTERFACE "RouterOS LAN interface" "LAN"
prompt ROS_GATEWAY_OPTION_NAME "RouterOS gateway DHCP option" "gw_to_mihomo"
prompt ROS_DNS_OPTION_NAME "RouterOS DNS DHCP option" "dns_to_adguard"
prompt ROS_OPTION_SET_NAME "RouterOS DHCP option set" "set_mihomo"
prompt OLD_GATEWAY_IP "Rollback gateway/DNS" "$ROS_IP"

valid_ipv4 "$ROS_IP" && valid_ipv4 "$MIHOMO_IP" && valid_ipv4 "$AGH_IP" || die "IPv4 格式错误"
case ${ENABLE_CLIENT_IPV6,,} in
  yes|y)
    ENABLE_CLIENT_IPV6=yes
    ROS_RA_LIFETIME=30m
    AGH_DISABLE_IPV6=false
    MIHOMO_CN_FAKE_IP_FILTER='geosite:cn'
    ;;
  no|n)
    ENABLE_CLIENT_IPV6=no
    ROS_RA_LIFETIME=none
    AGH_DISABLE_IPV6=true
    MIHOMO_CN_FAKE_IP_FILTER='__client_ipv6_disabled.invalid'
    ;;
  *) die "客户端 IPv6选项请输入 yes 或 no" ;;
esac
LAN_PREFIX=${LAN_CIDR#*/}
[[ $LAN_PREFIX =~ ^[0-9]+$ && $LAN_PREFIX -ge 8 && $LAN_PREFIX -le 30 ]] || die "LAN CIDR前缀无效: $LAN_CIDR"
qm status "$MIHOMO_VMID" >/dev/null 2>&1 && die "VMID $MIHOMO_VMID 已存在"
pct status "$AGH_CTID" >/dev/null 2>&1 && die "CTID $AGH_CTID 已存在"
pvesm status | awk '{print $1}' | grep -qx "$PVE_STORAGE" || die "存储不存在: $PVE_STORAGE"
ip link show "$PVE_BRIDGE" >/dev/null 2>&1 || die "网桥不存在: $PVE_BRIDGE"
ping -c 1 -W 1 "$MIHOMO_IP" >/dev/null 2>&1 && die "$MIHOMO_IP 已被占用"
ping -c 1 -W 1 "$AGH_IP" >/dev/null 2>&1 && die "$AGH_IP 已被占用"

MIHOMO_SECRET=$(random_hex 16)
SUBSTORE_BACKEND_PATH=$(random_hex 12)
AGH_ADMIN_PASSWORD=$(random_password)
CLOUD_USER=admin
CLOUD_PASSWORD=$MIHOMO_VM_PASSWORD
export LAN_CIDR ROS_IP ROS_IPV6_LINK_LOCAL PVE_BRIDGE PVE_STORAGE PVE_FILE_STORAGE
export MIHOMO_VMID MIHOMO_IP MIHOMO_DISK_GB MIHOMO_CORES MIHOMO_MEMORY_MB
export AGH_CTID AGH_IP AGH_DISK_GB AGH_CORES AGH_MEMORY_MB
export SUBSTORE_SUB_NAME MIHOMO_SECRET SUBSTORE_BACKEND_PATH AGH_ADMIN_PASSWORD MIHOMO_VM_PASSWORD
export MIHOMO_EXTRA_RULES_FILE
export ROS_LAN_INTERFACE ROS_GATEWAY_OPTION_NAME ROS_DNS_OPTION_NAME ROS_OPTION_SET_NAME OLD_GATEWAY_IP
export ENABLE_CLIENT_IPV6 ROS_RA_LIFETIME AGH_DISABLE_IPV6 MIHOMO_CN_FAKE_IP_FILTER
export DOWNLOAD_PROFILE APT_MIRROR GITHUB_PROXY GITHUB_PROXY_ALT MIHOMO_VERSION ZASHBOARD_VERSION AGH_VERSION

MIHOMO_EXTRA_RULES=''
if [[ -n $MIHOMO_EXTRA_RULES_FILE && -f $MIHOMO_EXTRA_RULES_FILE ]]; then
  MIHOMO_EXTRA_RULES=$(tr -d '\r' < "$MIHOMO_EXTRA_RULES_FILE" | sed 's/^/  /')
fi
export MIHOMO_EXTRA_RULES

cat >"$RUNTIME_DIR/config.env" <<EOF
LAN_CIDR=$LAN_CIDR
ROS_IP=$ROS_IP
ROS_IPV6_LINK_LOCAL=$ROS_IPV6_LINK_LOCAL
ENABLE_CLIENT_IPV6=$ENABLE_CLIENT_IPV6
PVE_BRIDGE=$PVE_BRIDGE
PVE_STORAGE=$PVE_STORAGE
PVE_FILE_STORAGE=$PVE_FILE_STORAGE
MIHOMO_VMID=$MIHOMO_VMID
MIHOMO_IP=$MIHOMO_IP
AGH_CTID=$AGH_CTID
AGH_IP=$AGH_IP
SUBSTORE_SUB_NAME=$SUBSTORE_SUB_NAME
DOWNLOAD_PROFILE=$DOWNLOAD_PROFILE
APT_MIRROR=$APT_MIRROR
GITHUB_PROXY=$GITHUB_PROXY
GITHUB_PROXY_ALT=$GITHUB_PROXY_ALT
MIHOMO_VERSION=$MIHOMO_VERSION
ZASHBOARD_VERSION=$ZASHBOARD_VERSION
AGH_VERSION=$AGH_VERSION
MIHOMO_VM_PASSWORD=$MIHOMO_VM_PASSWORD
MIHOMO_EXTRA_RULES_FILE=$MIHOMO_EXTRA_RULES_FILE
EOF
cat >"$RUNTIME_DIR/secrets.env" <<EOF
MIHOMO_SECRET=$MIHOMO_SECRET
SUBSTORE_BACKEND_PATH=$SUBSTORE_BACKEND_PATH
AGH_ADMIN_PASSWORD=$AGH_ADMIN_PASSWORD
CLOUD_USER=$CLOUD_USER
CLOUD_PASSWORD=$CLOUD_PASSWORD
EOF
chmod 600 "$RUNTIME_DIR"/*.env

render_template "$ROOT_DIR/templates/routeros-apply.rsc" "$RUNTIME_DIR/routeros-apply.rsc"
render_template "$ROOT_DIR/templates/routeros-rollback.rsc" "$RUNTIME_DIR/routeros-rollback.rsc"

if [[ $DRY_RUN == 1 ]]; then
  log "DRY_RUN 完成，未创建 VM/LXC"
  log "RouterOS脚本: $RUNTIME_DIR/routeros-apply.rsc"
  exit 0
fi

log "计划创建 VM $MIHOMO_VMID ($MIHOMO_IP) 和 CT $AGH_CTID ($AGH_IP)"
confirm "确认执行 PVE 变更？" || die "用户取消"

CLOUD_DIR="/var/lib/vz/template/iso"
CLOUD_IMAGE="$CLOUD_DIR/debian-13-genericcloud-amd64.qcow2"
run mkdir -p "$CLOUD_DIR"
if [[ ! -f $CLOUD_IMAGE ]]; then
  if [[ $DOWNLOAD_PROFILE == china ]]; then
    download_first "$CLOUD_IMAGE" \
      https://mirrors.ustc.edu.cn/debian-cdimage/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2 \
      https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2 \
      || die "Debian Cloud Image 下载失败"
  else
    download_first "$CLOUD_IMAGE" \
      https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2 \
      || die "Debian Cloud Image 下载失败"
  fi
fi

SSH_KEY_FILE="$RUNTIME_DIR/id_ed25519"
[[ -f "$SSH_KEY_FILE" ]] || run ssh-keygen -q -t ed25519 -N '' -f "$SSH_KEY_FILE"

run qm create "$MIHOMO_VMID" --name debian-mihomo --machine q35 --cpu host \
  --cores "$MIHOMO_CORES" --memory "$MIHOMO_MEMORY_MB" --scsihw virtio-scsi-single \
  --net0 "virtio,bridge=$PVE_BRIDGE" --agent enabled=1 --onboot 1
run qm importdisk "$MIHOMO_VMID" "$CLOUD_IMAGE" "$PVE_STORAGE"
IMPORTED_VOL=$(pvesm list "$PVE_STORAGE" --vmid "$MIHOMO_VMID" | awk '/vm-'"$MIHOMO_VMID"'-disk-0/{print $1; exit}')
[[ -n "$IMPORTED_VOL" ]] || die "无法识别导入磁盘"
run qm set "$MIHOMO_VMID" --scsi0 "$IMPORTED_VOL,discard=on,iothread=1" --boot order=scsi0
run qm resize "$MIHOMO_VMID" scsi0 "${MIHOMO_DISK_GB}G"
run qm set "$MIHOMO_VMID" --ide2 "$PVE_STORAGE:cloudinit" \
  --ciuser "$CLOUD_USER" --cipassword "$CLOUD_PASSWORD" \
  --sshkeys "$SSH_KEY_FILE.pub" --ipconfig0 "ip=$MIHOMO_IP/$LAN_PREFIX,gw=$ROS_IP" \
  --nameserver 223.5.5.5
run qm start "$MIHOMO_VMID"

wait_for 180 "Mihomo VM SSH" ssh -o StrictHostKeyChecking=no -o BatchMode=yes -i "$SSH_KEY_FILE" "$CLOUD_USER@$MIHOMO_IP" true
if [[ -z $ROS_IPV6_LINK_LOCAL ]]; then
  ROS_IPV6_LINK_LOCAL=$(ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_FILE" "$CLOUD_USER@$MIHOMO_IP" \
    "ip -6 route show default | awk '/proto ra/ {print \$3; exit}'" 2>/dev/null || true)
  if [[ -n $ROS_IPV6_LINK_LOCAL ]]; then
    log "自动发现 RouterOS IPv6 link-local: $ROS_IPV6_LINK_LOCAL"
    printf 'ROS_IPV6_LINK_LOCAL=%s\n' "$ROS_IPV6_LINK_LOCAL" >>"$RUNTIME_DIR/config.env"
  else
    warn "未发现 RouterOS IPv6默认路由；跳过 Mihomo专用IPv6静态路由"
  fi
fi
MIHOMO_CONFIG=$(render_template "$ROOT_DIR/templates/mihomo.yaml" /dev/stdout)
MIHOMO_CONFIG_B64=$(printf '%s' "$MIHOMO_CONFIG" | base64 -w0)
export MIHOMO_CONFIG_B64
scp -q -o StrictHostKeyChecking=no -i "$SSH_KEY_FILE" "$ROOT_DIR/scripts/provision-mihomo.sh" "$CLOUD_USER@$MIHOMO_IP:/tmp/provision-mihomo.sh"
ssh -tt -o StrictHostKeyChecking=no -i "$SSH_KEY_FILE" "$CLOUD_USER@$MIHOMO_IP" \
  "sudo env MIHOMO_CONFIG_B64='$MIHOMO_CONFIG_B64' MIHOMO_SECRET='$MIHOMO_SECRET' SUBSTORE_BACKEND_PATH='$SUBSTORE_BACKEND_PATH' SUBSTORE_SUB_NAME='$SUBSTORE_SUB_NAME' MIHOMO_IP='$MIHOMO_IP' MIHOMO_VM_PASSWORD='$MIHOMO_VM_PASSWORD' ROS_IPV6_LINK_LOCAL='$ROS_IPV6_LINK_LOCAL' APT_MIRROR='$APT_MIRROR' GITHUB_PROXY='$GITHUB_PROXY' GITHUB_PROXY_ALT='$GITHUB_PROXY_ALT' MIHOMO_VERSION='$MIHOMO_VERSION' ZASHBOARD_VERSION='$ZASHBOARD_VERSION' bash /tmp/provision-mihomo.sh"

TEMPLATE=$(pveam available --section system | awk '/debian-13-standard/ {print $2}' | tail -1)
[[ -n $TEMPLATE ]] || die "找不到 Debian 13 LXC 模板"
pveam list "$PVE_FILE_STORAGE" | grep -q "$TEMPLATE" || run pveam download "$PVE_FILE_STORAGE" "$TEMPLATE"
run pct create "$AGH_CTID" "$PVE_FILE_STORAGE:vztmpl/$TEMPLATE" --hostname adguard-home \
  --cores "$AGH_CORES" --memory "$AGH_MEMORY_MB" --swap 256 --rootfs "$PVE_STORAGE:$AGH_DISK_GB" \
  --net0 "name=eth0,bridge=$PVE_BRIDGE,ip=$AGH_IP/$LAN_PREFIX,gw=$ROS_IP,type=veth" \
  --unprivileged 1 --onboot 1 --nameserver 223.5.5.5 --searchdomain lan
run pct start "$AGH_CTID"
wait_for 60 "AdGuard LXC" pct exec "$AGH_CTID" -- true
run pct push "$AGH_CTID" "$ROOT_DIR/scripts/provision-adguard.sh" /root/provision-adguard.sh
run pct exec "$AGH_CTID" -- env AGH_ADMIN_PASSWORD="$AGH_ADMIN_PASSWORD" MIHOMO_IP="$MIHOMO_IP" AGH_DISABLE_IPV6="$AGH_DISABLE_IPV6" \
  APT_MIRROR="$APT_MIRROR" GITHUB_PROXY="$GITHUB_PROXY" GITHUB_PROXY_ALT="$GITHUB_PROXY_ALT" \
  AGH_VERSION="$AGH_VERSION" bash /root/provision-adguard.sh

log "请打开 http://$MIHOMO_IP:3001/ 添加订阅，名称必须是: $SUBSTORE_SUB_NAME"
read -r -p "添加完成后按 Enter 继续验证..."

wait_for 30 "Sub-Store output" curl -fsS "http://$MIHOMO_IP:3001/$SUBSTORE_BACKEND_PATH/download/$SUBSTORE_SUB_NAME?target=ClashMeta"
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_FILE" "$CLOUD_USER@$MIHOMO_IP" "sudo systemctl restart mihomo"
sleep 5
curl -fsS "http://$MIHOMO_IP:9090/ui/" >/dev/null
dig "@$AGH_IP" google.com A +short | grep -q '^198\.18\.' || die "AGH → Mihomo Fake-IP 验证失败"
dig "@$AGH_IP" doubleclick.net A +short | grep -q '^0\.0\.0\.0$' || warn "广告域名未被阻断，请检查过滤列表"

cat <<EOF

部署完成。

Zashboard:   http://$MIHOMO_IP:9090/ui/
Controller:  http://$MIHOMO_IP:9090
Secret:      $MIHOMO_SECRET
Sub-Store:   http://$MIHOMO_IP:3001/
Backend:     http://$MIHOMO_IP:3001/$SUBSTORE_BACKEND_PATH
AdGuard:     http://$AGH_IP:3000/
AGH user:    admin
AGH password:$AGH_ADMIN_PASSWORD

RouterOS apply script:
  $RUNTIME_DIR/routeros-apply.rsc
RouterOS rollback script:
  $RUNTIME_DIR/routeros-rollback.rsc
EOF
