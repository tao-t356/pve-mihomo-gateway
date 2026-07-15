# 《PVE下搭建 RouterOS + Mihomo + AdGuard Home + Zashboard + Sub-Store》视频文案

> 定位：面向第一次接触 PVE、透明代理和 DNS分流的新手。
>
> 建议时长：35～45分钟。
>
> 项目地址：<https://github.com/tao-t356/pve-mihomo-gateway>

## 一、视频包装

### 标题建议

主标题：

> 一台PVE小主机搞定全屋网络：RouterOS + Mihomo + AdGuard Home小白教程

备选标题：

- 告别OpenWrt旁路由：PVE下部署Mihomo透明网关与AGH去广告
- 从零理解家庭透明代理：ROS主路由、Mihomo、AGH、Sub-Store到底怎么配
- N100软路由终极方案？PVE + ROS + Mihomo + AGH完整实战

### 封面文字建议

```text
PVE全屋透明代理
ROS + Mihomo + AGH
小白一键部署
```

封面尽量只保留三行大字，避免塞入过多软件Logo。

### 视频简介模板

```text
本期视频从原理到实战，介绍如何在已经安装PVE和RouterOS主路由的环境中，
使用交互式脚本部署Mihomo、Zashboard、Sub-Store和AdGuard Home。

你将学会：
1. 每个组件分别负责什么；
2. 为什么DNS要先经过AGH，再交给Mihomo；
3. 如何让国内IPv4/IPv6直连、国外流量透明代理；
4. 如何用Sub-Store管理节点、用Zashboard切换分组；
5. 如何只让指定设备使用透明代理；
6. 断网时如何快速回滚。

项目地址：
https://github.com/tao-t356/pve-mihomo-gateway

请勿在评论区、Issue或截图中公开订阅链接、PVE密码和面板密钥。
```

## 二、录制前准备

录制前隐藏或打码：

- PVE、RouterOS、Mihomo和AGH真实密码；
- 代理订阅链接；
- Mihomo控制器密钥；
- Sub-Store后端随机路径；
- 宽带账号、PPPoE密码；
- 公网IPv4、完整公网IPv6和设备MAC地址；
- 节点的UUID、密码、域名和服务器地址。

建议提前准备：

- 一个干净的浏览器配置文件；
- PVE网页后台；
- RouterOS WinBox；
- 一个用于演示的脱敏订阅；
- 一台测试电脑或手机；
- 录制失败时可使用的备用网络。

重要边界需要在视频开头说清楚：

> 当前脚本从“PVE已经安装、RouterOS CHR已经能正常拨号和上网”开始。脚本不会自动填写宽带账号，也不会自动判断WAN和LAN物理口。主路由基础配置错误可能导致全家断网，因此PPPoE、WAN、LAN、DHCP和NAT仍属于前置工作。

RouterOS CHR建议使用官方镜像和合法许可证。不要在教程中演示许可证绕过、Keygen或第三方破解镜像。

## 三、完整视频脚本

## 00:00－01:20 开场：这套方案解决什么问题

### 画面

- 快速展示PVE虚拟机列表；
- 切换到Zashboard节点分组；
- 展示AdGuard Home查询统计；
- 手机打开国内网站和YouTube；
- 最后展示网络拓扑图。

### 口播

> 大家好，今天我们用一台安装了PVE的小主机，搭建一套适合家庭长期使用的透明网关。
>
> 主路由使用RouterOS，Mihomo负责透明代理和流量分流，AdGuard Home负责广告过滤和DNS管理，Zashboard负责切换节点，Sub-Store负责订阅和节点整理。
>
> 最终效果是：普通设备不需要安装代理软件，只要获得指定的网关和DNS，就能按照规则自动分流；国内网站直连，Google、YouTube等国外服务走代理，TikTok、AI和EMBY可以分别选择不同节点；有IPv6的家庭还可以让国内IPv6直连，同时防止国外IPv6绕过代理。
>
> 这期不会只给大家复制命令。我会解释每一个组件为什么存在，以及数据到底经过了哪里。

## 01:20－04:30 先理解五个组件

### 画面

显示以下拓扑：

```text
                         ┌────────────────────┐
手机 / 电脑 ──网关──────→│ Mihomo 192.168.1.10│──→ RouterOS ──→ 互联网
    │                    │ TUN / 分流 / Fake-IP│
    │                    └─────────▲──────────┘
    │                              │ DNS上游 :1053
    └──DNS──→ AdGuard Home ────────┘
              192.168.1.8

Sub-Store ──提供节点──→ Mihomo
Zashboard ──选择节点──→ Mihomo
```

### 口播

> PVE是虚拟化平台，负责在同一台小主机里运行多个相互隔离的系统。
>
> RouterOS是主路由，负责拨号、DHCP、NAT、IPv6前缀和基础防火墙。它仍然是整个家庭网络的出口。
>
> Mihomo不是主路由，它是一台位于LAN里的透明网关。需要代理的设备把IPv4网关指向Mihomo，Mihomo判断流量应该直连还是走节点，然后再把数据交给RouterOS出网。
>
> AdGuard Home简称AGH，负责广告过滤、自定义黑白名单、DNS查询日志和局域网DNS管理。
>
> Sub-Store是节点仓库，负责添加订阅、合并、过滤和重命名节点。它不直接转发网络流量。
>
> Zashboard是Mihomo控制面板，用来查看连接、查看规则命中，以及给不同分组选择节点。

## 04:30－07:30 为什么不是一个软件全部完成

### 口播

> 很多新手会问，为什么不让Sub-Store直接生成全部分流配置？它确实可以生成完整配置，但这样每次更新模板，都可能同时覆盖DNS、TUN、分组和规则。
>
> 我们把经常变化的节点交给Sub-Store，把相对稳定的分流规则留在Mihomo。这样即使Sub-Store临时不可用，Mihomo仍然可以使用已经缓存的节点继续工作。
>
> Zashboard只负责运行时选择。例如AI选择美国节点，TikTok选择新加坡节点，EMBY选择香港节点。它适合日常操作，但不适合编辑整份YAML配置。
>
> 这种拆分的优势是职责清楚：节点坏了看Sub-Store，分流错误看Mihomo，广告没过滤看AGH，拨号和DHCP有问题看RouterOS。

## 07:30－10:00 DNS为什么是 AGH → Mihomo

### 画面

```text
客户端
  ↓ 192.168.1.8:53
AdGuard Home：过滤广告、记录日志
  ↓ 192.168.1.10:1053
Mihomo DNS：Fake-IP、国内外DNS分流、IPv6策略
  ↓
国内DoH / 国外DoH
```

### 口播

> DNS请求先到AGH，因为我们希望广告域名在最前面就被拦截，也希望在AGH界面里看到每台设备查询了什么。
>
> AGH过滤完成后，再把请求交给Mihomo的1053端口。Mihomo知道哪些域名属于国内、哪些域名需要代理，也负责Fake-IP映射，所以它必须参与最终解析。
>
> 如果AGH直接查询公共DNS，Mihomo可能失去Fake-IP映射，或者出现域名解析线路和代理出口不一致的问题。
>
> Mihomo的dns-hijack是安全兜底。如果某个应用偷偷访问8.8.8.8的53端口，Mihomo会把普通DNS接管，防止泄漏。但浏览器DoH和Android私人DNS使用的是加密连接，53端口劫持抓不到，所以客户端不要设置外部私人DNS。

## 10:00－12:30 硬件与前置条件

### 画面

展示新手准备清单。

### 口播

> 硬件方面，8GB内存可以运行，推荐16GB。系统盘128GB可以用，但256GB以上更宽松。至少准备WAN和LAN两个物理网口，并保留一台可以插网线的电脑用于故障恢复。
>
> 存储方面，local-lvm至少保留10GB真实可用空间，推荐20GB；local至少保留2GB，用来保存Cloud Image和LXC模板。
>
> 注意LVM-Thin显示的虚拟磁盘大小不等于实际占用。脚本会新建5GB的Mihomo VM和3GB的AGH LXC，不会缩小已有虚拟机，也不会碰已有的ROS、OpenWrt或NAS虚拟机。

### 屏幕命令

在PVE Shell执行：

```bash
pveversion
pvesm status
ip -br address
qm list
pct list
```

### 解说重点

- 确认网桥名称，通常是`vmbr0`；
- 确认`local-lvm`和`local`存在；
- 准备一个空闲VMID和一个空闲CTID；
- Mihomo与AGH地址必须位于DHCP动态池之外；
- PVE自身必须能上网。

## 12:30－14:30 IP规划

### 画面

| 用途 | 教程示例 |
|---|---|
| LAN网段 | `192.168.1.0/24` |
| RouterOS | `192.168.1.2` |
| PVE | `192.168.1.7` |
| AdGuard Home | `192.168.1.8` |
| Mihomo | `192.168.1.10` |

### 口播

> IP地址可以不同，但必须处于同一个LAN，而且不能重复。Mihomo和AGH最好放在DHCP动态池之外。
>
> 客户端最终使用的IPv4网关是Mihomo，DNS是AGH。Mihomo自己的上游网关仍然是RouterOS，AGH自己的上游网关也仍然是RouterOS，因此不会形成路由环路。

## 14:30－16:00 RouterOS备份与检查

### 画面与命令

```routeros
/export hide-sensitive file=before-pve-mihomo
/system resource print
/ip address print
/ip dhcp-server print
/ip dhcp-server network print
/ip dhcp-server lease print
/ipv6 nd print detail
```

### 口播

> 在修改主路由以前必须备份。hide-sensitive会隐藏大部分敏感信息，但公开截图前仍然要人工检查。
>
> 记录LAN接口名称，它可能叫LAN、bridge或bridge-lan。后面的脚本需要使用完全相同的名称。

## 16:00－18:00 下载项目与安装依赖

### 屏幕命令

```bash
apt-get update
apt-get install -y curl jq openssl gettext-base openssh-client dnsutils
```

GitHub直连：

```bash
git clone https://github.com/tao-t356/pve-mihomo-gateway.git
cd pve-mihomo-gateway
```

大陆网络下载：

```bash
curl -fL https://ghfast.top/https://github.com/tao-t356/pve-mihomo-gateway/archive/refs/heads/main.tar.gz \
  | tar -xz
cd pve-mihomo-gateway-main
```

### 口播

> 大陆下载模式会优先使用中科大Debian镜像，并为GitHub Release设置多个回退地址。第三方GitHub代理不能保证永久可靠，高安全需求环境建议使用自己的镜像。

## 18:00－24:00 运行交互式安装器

### 屏幕命令

```bash
chmod +x install.sh scripts/*.sh
./install.sh
```

### 逐项解释

录屏时不要快速回车跳过，应解释主要选项：

1. `LAN CIDR`：家庭LAN网段，例如`192.168.1.0/24`。
2. `RouterOS IPv4`：主路由LAN地址。
3. `RouterOS LAN link-local IPv6`：可以留空，向导会尝试自动发现。
4. `是否给手机/电脑启用国内 IPv6直连`：有IPv6-PD选择`yes`，没有运营商IPv6选择`no`。
5. `PVE LAN bridge`：一般为`vmbr0`。
6. `VM/LXC storage`：一般为`local-lvm`。
7. `Template storage`：一般为`local`。
8. `Mihomo VMID`与`AGH CTID`：必须未被占用。
9. `Mihomo IPv4`与`AGH IPv4`：必须未被占用。
10. CPU、内存、磁盘：默认Mihomo为4共享核心、2GB、5GB；AGH为4共享核心、512MB、3GB。
11. `Sub-Store subscription name`：记住这个名字，稍后在Sub-Store里必须创建同名订阅。
12. `RouterOS LAN interface`：填写前面记录的LAN接口名称。

### 口播

> 脚本首先检查IP、VMID、CTID、存储和网桥，发生冲突时直接停止，不会覆盖现有虚拟机。
>
> Mihomo使用Debian 13 Cloud Image创建全新VM，不通过克隆旧系统，也不会尝试在线缩小虚拟磁盘。
>
> 密钥和面板密码会随机生成并保存在PVE的受限目录中，不会写进GitHub仓库。

### 脚本创建的内容

```text
Debian VM
├── Mihomo
├── Zashboard
└── Sub-Store

Debian LXC
└── AdGuard Home
```

## 24:00－27:00 在Sub-Store添加订阅

### 画面

打开：

```text
http://MIHOMO_IP:3001/
```

### 操作

1. 新增单条订阅；
2. 名称必须与安装器填写的名称相同；
3. 粘贴订阅地址；
4. 保存；
5. 查看节点是否成功解析；
6. 回到PVE终端继续向导。

### 口播

> Sub-Store只管理节点。节点更新后，Mihomo的Provider会定期拉取。订阅地址不要在视频里展示，也不要提交到GitHub Issue。

> 如果提示后端无法连接，首先确认3001端口是否监听，并检查浏览器中填写的后端地址是否与当前页面协议一致。HTTPS页面请求HTTP后端也可能被浏览器拦截。

## 27:00－30:00 Zashboard查看分组和选择节点

### 画面

打开：

```text
http://MIHOMO_IP:9090/ui/
```

### 口播

> Zashboard连接的是Mihomo控制接口。第一次连接时需要填写控制器地址和密钥，密钥保存在PVE运行时目录，录屏时必须打码。

展示以下分组：

```text
PROXY / AUTO / HK / JP / SG / US
TIKTOK / EMBY / AI / YOUTUBE
TELEGRAM / GOOGLE / MICROSOFT / APPLE
AD-BLOCK / CHINA / FINAL
```

演示：

- `CHINA`选择`DIRECT`；
- `AI`选择美国节点；
- `TIKTOK`选择新加坡或日本节点；
- `EMBY`选择适合媒体服务器的节点；
- `FINAL`选择`PROXY`。

### 原理解释

> Sub-Store中的全部节点通过Provider进入这些分组。Zashboard负责选择，不负责创建持久化规则。

> Mihomo规则从上到下匹配，第一条命中后停止，因此EMBY、TikTok和AI等具体规则必须放在国内规则和FINAL规则之前。

## 30:00－32:00 AdGuard Home设置与验证

### 画面

打开：

```text
http://AGH_IP:3000/
```

### 口播

> 脚本已经完成AGH初始化，加入默认过滤器和anti-AD，并把上游DNS设置为Mihomo的1053端口。

展示：

- 查询日志；
- 过滤器；
- 自定义过滤规则；
- DNS上游；
- 客户端列表。

强调：

> AGH负责过滤和日志，Mihomo负责Fake-IP、国内外DoH与IPv6策略。AGH不是代理软件，网页流量不会穿过AGH。

## 32:00－35:00 应用RouterOS脚本

### PVE画面

```bash
sed -n '1,200p' /etc/pve-mihomo-gateway/routeros-apply.rsc
```

### 口播

> 安装器不会直接登录或修改RouterOS，而是生成应用脚本和回滚脚本。这样用户可以先审查，再粘贴到RouterOS Terminal。

生成文件：

```text
/etc/pve-mihomo-gateway/routeros-apply.rsc
/etc/pve-mihomo-gateway/routeros-rollback.rsc
```

应用脚本会：

- 备份RouterOS配置；
- 创建DHCP网关Option，指向Mihomo；
- 创建DHCP DNS Option，指向AGH；
- 创建`set_mihomo` Option Set；
- 根据安装选择开启或关闭客户端IPv6默认路由广播；
- 不直接修改所有设备的全局网关。

### WinBox操作

```text
IP → DHCP Server → Leases
→ 选择测试设备
→ Make Static
→ DHCP Option Set：set_mihomo
```

### 口播

> 先只绑定一台测试设备，不要一上来修改整个DHCP网络。未绑定设备仍使用RouterOS原来的网关和DNS，即使Mihomo配置错误，家里其他设备也不会全部断网。

## 35:00－38:00 IPv4、IPv6与DNS防泄漏测试

### 测试设备设置

```text
IPv4网关：Mihomo IP
DNS：AdGuard Home IP
```

### Windows命令

```powershell
ipconfig /all
nslookup www.baidu.com 192.168.1.8
nslookup www.google.com 192.168.1.8
nslookup -type=AAAA www.jd.com 192.168.1.8
nslookup -type=AAAA www.google.com 192.168.1.8
```

### 预期结果

- 国内域名返回真实IPv4；
- 启用客户端IPv6时，京东等国内域名返回真实IPv6；
- 国外域名A记录可返回`198.18.0.0/16`范围的Fake-IP；
- 国外域名不返回AAAA；
- Zashboard中可以看到国内连接命中`CHINA → DIRECT`；
- Google和YouTube命中对应代理分组。

### 口播

> Fake-IP不是网站的真实服务器地址，而是Mihomo在局域网内部使用的映射。设备连接Fake-IP后，Mihomo知道它原来对应哪个域名，再按照域名规则选择出口。

> 安全双栈模式并不是把所有IPv6都交给Mihomo透明代理，而是让国内域名获得真实AAAA并通过RouterOS直连；国外域名不提供AAAA，强制回到IPv4透明代理。这种方式实现简单、稳定，也能保留国内IPv6 CDN优势。

### 手机注意事项

- 重新连接Wi-Fi以刷新RA和DHCP信息；
- Android私人DNS设为关闭或自动；
- 浏览器安全DNS不要指定外部DoH；
- 使用`test-ipv6.com`验证IPv6；
- 使用DNS泄漏测试只能作为参考，还要结合Zashboard连接记录判断。

## 38:00－41:30 常见故障排查

### 故障一：客户端完全不能上网

依次检查：

```text
能否ping RouterOS
能否ping Mihomo
能否ping AGH
网关是否为Mihomo
DNS是否为AGH
Mihomo服务是否运行
AGH上游是否为Mihomo:1053
```

不要同时修改网关、DNS、IPv6和节点，应该一次只改一个变量。

### 故障二：能ping IP，但打不开域名

重点检查：

- AGH的53端口；
- Mihomo的1053端口；
- AGH是否禁用了AAAA；
- AGH上游是否可达；
- 客户端是否启用了私人DNS；
- Fake-IP DNS是否被下发给了不经过Mihomo的设备。

> 如果设备网关是RouterOS，却使用会返回Mihomo Fake-IP的AGH DNS，那么该设备可能无法访问Fake-IP。测试阶段应保证“网关Mihomo、DNS AGH”成对使用；或者在电脑上开启自己的TUN代理软件。

### 故障三：国内网站变慢

检查Zashboard连接详情：

- 国内域名是否命中`CHINA → DIRECT`；
- `CHINA`是否误选了代理节点；
- DNS响应时间是否过高；
- PPPoE MTU/MSS是否正确；
- 国内IPv6是否正常；
- 浏览器是否使用了外部安全DNS。

### 故障四：Sub-Store后端无法连接

- 检查Mihomo VM的3001端口；
- 检查Docker容器；
- 检查前端填写的后端地址和随机路径；
- 检查HTTP/HTTPS混合内容；
- 不要公开后端随机路径。

### 故障五：PVE克隆或创建虚拟机失败

```bash
pvesm status
vgs
lvs -a -o lv_name,vg_name,lv_size,data_percent,metadata_percent,segtype
df -h
```

> local目录有空间不代表local-lvm有空间。LVM-Thin接近100%时，虚拟机可能异常，应该先释放或扩容，而不是继续克隆。

## 41:30－43:00 回滚方法

### 画面

```bash
sed -n '1,200p' /etc/pve-mihomo-gateway/routeros-rollback.rsc
```

### 口播

> 如果测试设备不能上网，最快的恢复方式是先把设备网关和DNS改回RouterOS，然后从DHCP租约中移除`set_mihomo`。

> RouterOS回滚脚本会恢复生成的DHCP网关和DNS Option。安装前的完整RouterOS导出文件则用于更严重的恢复场景。

> 不要因为代理故障去重置整个PVE或RouterOS。先恢复客户端网关，通常几十秒就能恢复正常网络。

## 43:00－45:00 日常维护与总结

### 口播

> 日常增加和删除节点，在Sub-Store里操作；切换分组节点，在Zashboard里操作；增加网站分流，修改Mihomo的rules；广告白名单和黑名单，在AdGuard Home里操作；拨号、DHCP和IPv6前缀问题，则回到RouterOS检查。

> 这套方案最大的优势不是软件数量多，而是每个组件只做自己最擅长的事情，同时仍然保留故障隔离和快速回滚能力。

> 如果你是新手，记住三个原则：第一，先备份；第二，只测试一台设备；第三，网关和DNS要成对修改。只要遵守这三个原则，即使配置失败，也不会让全家网络一起掉线。

> 项目地址放在简介和置顶评论。请不要把订阅链接、密码或密钥发到评论区。我们下期再介绍如何增加自定义分流规则和按设备分配不同策略。

## 四、建议增加的后续视频

1. 《Mihomo分流规则详解：DOMAIN、GEOSITE、GEOIP怎么选》
2. 《Sub-Store从入门到进阶：合并、过滤、重命名节点》
3. 《AdGuard Home误杀排查与家庭DNS重写》
4. 《RouterOS DHCP Option Set：让不同设备使用不同网关》
5. 《家庭IPv6防泄漏：为什么有地址不等于安全》
6. 《Mihomo故障排查：Fake-IP、TUN、DNS和MTU》

## 五、置顶评论模板

```text
项目地址：
https://github.com/tao-t356/pve-mihomo-gateway

安装前请确认：
1. PVE正常联网；
2. RouterOS已经完成WAN、LAN、DHCP和NAT；
3. Mihomo与AGH使用的IP没有被占用；
4. local-lvm至少有10GB真实可用空间；
5. 已备份RouterOS配置；
6. 先只测试一台设备。

请勿在评论区公开订阅链接、PVE密码、控制器密钥和Sub-Store后端路径。
```

