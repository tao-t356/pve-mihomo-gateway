# PVE Mihomo Gateway Wizard

从一台已安装好的 Proxmox VE 开始，交互式部署 RouterOS 配套的家庭透明网关：

```text
RouterOS 主路由
├── Debian Cloud VM：Mihomo + Zashboard + Sub-Store
└── Debian LXC：AdGuard Home
```

默认示例：RouterOS `192.168.1.2`、Mihomo `192.168.1.10`、AdGuard Home `192.168.1.8`。

## 特性

- 使用 Debian 13 Generic Cloud Image，新建 VM，不克隆或缩小已有磁盘。
- Mihomo TUN、Fake-IP、国内外 DoH、常用业务分组和 EMBY 规则。
- AdGuard Home 默认过滤器与 anti-AD，DNS 上游指向 Mihomo。
- 客户端 IPv4、Mihomo 双栈；客户端不使用 IPv6 默认路由，Mihomo可连接纯 IPv6节点。
- 生成 RouterOS 7 应用和回滚脚本，不直接登录或修改主路由。
- VMID、CTID 或 IP 冲突时停止，不覆盖已有资源。

## PVE依赖

```bash
apt-get update
apt-get install -y curl jq openssl gettext-base openssh-client dnsutils
```

## 运行

GitHub直连：

```bash
git clone https://github.com/tao-t356/pve-mihomo-gateway.git
cd pve-mihomo-gateway
```

大陆网络无代理下载：

```bash
curl -fL https://ghfast.top/https://github.com/tao-t356/pve-mihomo-gateway/archive/refs/heads/main.tar.gz \
  | tar -xz
cd pve-mihomo-gateway-main
```

开始安装：

```bash
chmod +x install.sh scripts/*.sh
./install.sh
```

只生成配置与 RouterOS脚本：

```bash
DRY_RUN=1 ./install.sh
```

## 运行时输出

```text
/etc/pve-mihomo-gateway/config.env
/etc/pve-mihomo-gateway/secrets.env
/etc/pve-mihomo-gateway/routeros-apply.rsc
/etc/pve-mihomo-gateway/routeros-rollback.rsc
```

管理地址：

- Zashboard：`http://MIHOMO_IP:9090/ui/`
- Sub-Store：`http://MIHOMO_IP:3001/`
- AdGuard Home：`http://AGH_IP:3000/`

订阅不会写入项目文件。向导部署完成后会暂停，提示管理员在 Sub-Store 中新增指定名称的订阅，再继续验收。

生成的 RouterOS脚本会创建或更新 DHCP Option Set。需要代理的静态租约应绑定该 Option Set；未绑定的设备继续使用 RouterOS默认网关和 DNS。

## 大陆网络下载策略

`china` 下载模式默认使用：

- Debian Cloud Image：中科大镜像，失败后回退 Debian官方源。
- Debian APT：中科大镜像。
- Mihomo、Zashboard：`ghfast.top`、`gh-proxy.com`、GitHub官方源依次回退。
- Sub-Store：南京大学 GHCR镜像，失败后回退官方 GHCR。
- AdGuard Home：AdGuard官方静态站，失败后回退 GitHub代理和官方 Release。

GitHub代理属于第三方服务，不能视为永久可靠或可信。向导会显示实际下载地址，并允许在交互阶段替换代理前缀；高安全需求环境建议使用自己的对象存储或镜像代理。
