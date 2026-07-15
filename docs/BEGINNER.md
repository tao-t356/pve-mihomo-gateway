# 新手安装前准备清单

当前版本负责部署 Mihomo VM、Zashboard、Sub-Store、AdGuard Home LXC，并生成 RouterOS配置脚本。

## 必须已经完成

- PVE已安装并能进入网页后台。
- RouterOS CHR已安装并能正常作为主路由工作。
- RouterOS已经完成 WAN、LAN、拨号或上级路由、DHCP和 NAT配置。
- PVE主机自身能够访问互联网。

当前版本不自动安装 RouterOS，也不配置 PPPoE账号或物理网口。主路由配置错误可能导致全家断网，因此仍作为前置准备。

## 硬件建议

- 支持虚拟化的 x86小主机。
- 至少两个物理网口：WAN和 LAN。
- 8GB内存，推荐16GB。
- 128GB SSD，推荐256GB以上。
- 一台可以用网线连接 LAN的电脑，用于故障恢复。

空间建议：

- `local-lvm` 至少10GB实际可用，推荐20GB。
- `local` 至少2GB可用，用于 Cloud Image和 LXC模板。

## 账号和资料

准备好：

- PVE root账号和密码。
- RouterOS管理员账号，能够打开 Terminal。
- 代理订阅链接。不要发到群聊、Issue或公开日志。
- 如果 RouterOS负责 PPPoE，保存好宽带账号和密码。

安装前备份 RouterOS：

```routeros
/export hide-sensitive file=before-pve-mihomo
```

## IP规划

先记录以下信息：

| 用途 | 示例 |
|---|---|
| LAN网段 | `192.168.1.0/24` |
| RouterOS | `192.168.1.2` |
| PVE | `192.168.1.7` |
| AdGuard Home | `192.168.1.8` |
| Mihomo | `192.168.1.10` |

Mihomo和 AGH地址必须未被占用，最好位于 DHCP动态池之外，并与 RouterOS、PVE处于同一 LAN。

## PVE检查

在 PVE Shell执行：

```bash
pveversion
pvesm status
ip -br address
qm list
pct list
```

需要知道：

- LAN网桥名称，通常是 `vmbr0`。
- VM/LXC存储，通常是 `local-lvm`。
- 模板存储，通常是 `local`。
- 准备使用的 VMID和 CTID没有被占用。

安装依赖：

```bash
apt-get update
apt-get install -y curl jq openssl gettext-base openssh-client dnsutils
```

## RouterOS检查

建议使用 RouterOS 7稳定版。执行：

```routeros
/system resource print
/ip address print
/ip dhcp-server print
/ip dhcp-server network print
/ip dhcp-server lease print
/ipv6 nd print detail
```

需要知道 LAN接口名称，例如 `LAN` 或 `bridge`。需要走代理的设备，建议提前设置为静态 DHCP租约。

## IPv6不是必需条件

- 没有运营商 IPv6时，IPv4透明代理、AGH和所有面板仍能使用。
- 有 IPv6时，向导会自动尝试发现 RouterOS链路本地地址。
- 默认不让普通客户端使用 IPv6默认路由，避免绕过代理。
- Mihomo自身可保留 IPv6，用于连接纯 IPv6节点。

自动发现失败可以留空，不影响 IPv4功能。

## 安装时会创建

- Debian Cloud VM：默认4共享核心、2GB内存、5GB磁盘。
- Debian LXC：默认4共享核心、512MB内存、3GB磁盘。
- `/etc/pve-mihomo-gateway/` 下的配置、密钥和 RouterOS脚本。

安装过程中会暂停一次，让用户打开 Sub-Store新增订阅。订阅名称必须与向导中填写的名称一致。

## 推荐上线顺序

1. 先用一台电脑手动设置 Mihomo网关和 AGH DNS。
2. 测试国内网站、Google、YouTube、TikTok和 EMBY。
3. 在 RouterOS粘贴生成脚本。
4. 只给少量静态租约绑定 DHCP Option Set。
5. 稳定运行一天后再扩大范围。

## 常见错误

- Mihomo或 AGH地址落在 DHCP动态池内，之后发生冲突。
- 给不经过 Mihomo的设备下发 Fake-IP DNS。
- 直接修改全局 DHCP网关，导致全网同时断线。
- 没有备份 RouterOS配置。
- 公开订阅链接、PVE密码或面板密钥。
- LVM-Thin空间耗尽导致 VM异常。

