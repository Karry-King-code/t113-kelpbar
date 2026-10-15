# 蓝牙：手机/电脑连接开发板 ✅ 已完成

> **状态：✅ 已完成（2026-10-12）**
> 手机 + 电脑双双配对成功，建立链路密钥，ACL 数据双向传输。

---

## 成功证据（btmon 抓到的完整 HCI 交互）

```
< HCI Command: IO Capability Request
    IO capability: NoInputNoOutput (0x03)        ← 免密配对能力
> HCI Event: User Confirmation Request
    User Confirmation Request Reply              ← 自动确认成功
> HCI Event: Simple Pairing Complete             ← ★ 配对完成
> HCI Event: Link Key Notification
    Link key: 3737867db1c199c77134cd07a3e89002   ← ★ 链路密钥生成
@ MGMT Event: New Link Key                       ← 密钥已保存
```

**设备端验证**：
```
hci0: UP RUNNING PSCAN ISCAN
BD Address: 34:75:63:48:4A:AD
RX bytes:14022  acl:77   ← 双向 ACL 数据传输
TX bytes:9700   acl:77
```

**用户端验证**：
- 电脑：设备列表出现 `T113-KelpBar` + "删除此设备"按钮 = 已配对
- 手机：`已配对的蓝牙设备 → T113-KelpBar` = 已配对

---

## ★ 成功配方（核心！照这个做就能通）

### 前提：芯片必须处于「冷启动」状态

**这是本关最重要的经验**：RTL8723DS 的蓝牙供电域 = VBAT 常供电，
一旦初始化失败/被打断，芯片进入「假死」，**软重启、模块重载、rfkill 切换都救不回来**，
**唯一复位方式 = 整机拔掉所有 USB 线，等 15 秒再上电**。

### 一键脚本（板上 /root/bt_up.sh）

```sh
#!/bin/sh
# [1] 清理旧状态（含旧配对记录 —— 这是"配对码不匹配"的根源）
killall -9 rtk_hciattach hciattach bluetoothd bluetoothctl 2>/dev/null
sleep 1
rm -rf /var/lib/bluetooth/* 2>/dev/null

# [2] 启动 HCI 链路（含固件下载）
rtk_hciattach -n -s 115200 /dev/ttyS1 rtk_h5 > /tmp/bt.log 2>&1 &

# 等 hci0 出现（实测约 4 秒）
i=0
while [ ! -d /sys/class/bluetooth/hci0 ]; do
    sleep 1; i=$((i+1))
    [ $i -gt 40 ] && echo "hci0 TIMEOUT" && tail -6 /tmp/bt.log && exit 1
done

# [3] 配置（免密配对 + 可发现 + 可绑定）
hciconfig hci0 up
btmgmt power on
btmgmt ssp on           # 安全简单配对
btmgmt io-cap 3         # NoInputNoOutput = 免密 Just Works
btmgmt bondable on      # ★ 少了这个会导致"已拒绝配对"
btmgmt connectable on
btmgmt name T113-KelpBar
hciconfig hci0 class 0x000104    # ★ 类别必须设置，空的会被安卓隐藏
hciconfig hci0 piscan            # 可发现+可连接
```

**执行**：`sh /root/bt_up.sh`（或等开机自启，已写进 rc.local）

### 然后配对

手机/电脑搜索 → 找到 `T113-KelpBar` → 点它 → **免密直接配对成功**

---

## 五个必备条件（少一个都不行）

| # | 条件 | 命令 | 缺了会怎样 |
|---|---|---|---|
| 1 | 芯片冷启动 | 拔线 15 秒 | 固件下载超时，hci0 建不出来 |
| 2 | 清旧配对记录 | `rm -rf /var/lib/bluetooth/*` | 报"配对码不匹配" |
| 3 | SSP + io-cap=3 | `btmgmt ssp on; btmgmt io-cap 3` | 手机要 PIN 码，输错失败 |
| 4 | **bondable on** | `btmgmt bondable on` | 报"已拒绝配对" |
| 5 | **设置 class** | `hciconfig hci0 class 0x000104` | 安卓隐藏该设备（搜不到） |

---

## 已排除/已解决的坑（完整清单）

| # | 症状 | 真因 | 解法 |
|---|---|---|---|
| 1 | 驱动是 XR829 → sdio timeout | 板载芯片是 Realtek RTL8723DS | 换 rtl8723ds 驱动 |
| 2 | 固件补丁下载超时（40 次重发） | **config 文件指示芯片切到 4.9M 波特+流控**（T113 UART1 最高 1.5M） | **移除 config 文件**（用 efuse 默认设置） |
| 3 | `CONFIG_BT_HCIUART_3WIRE=y` 被静默丢弃 | 依赖链 SERIAL_DEV_BUS → BT_HCIUART_SERDEV 未开 | 补 `CONFIG_SERIAL_DEV_BUS=y` |
| 4 | `get wifi_sdc_id failed` | dts 父节点 rfkill@0 是 disabled | 改 okay |
| 5 | 芯片假死跨软重启 | BT 供电域 VBAT 常供电 | **整机断电 15 秒** |
| 6 | adb shell 里 `&` 后台进程被杀 | 会话退出连带杀子进程 | 用持久会话跑 `/root/bt_up.sh` |
| 7 | 多进程抢占 ttyS1 | 旧 hciattach 进程残留 | `killall -9` + 按 PID 杀 |
| 8 | 手机搜不到板子 | ①class=0 被安卓隐藏 ②SSP 未开 | 设 class + `btmgmt ssp on` |
| 9 | "配对码不匹配" | 旧配对记录残留 + 走传统 PIN 配对 | 清 `/var/lib/bluetooth` + io-cap=3 |
| 10 | "已拒绝配对" | **`bondable` 未开** | `btmgmt bondable on` |
| 11 | 手机静默失败（无错误提示） | 缺 SDP 服务记录 | 启动 `bluetoothd`（含 SDP server） |

---

## 关于"已配对"vs"已连接"

| 名词 | 含义 | 本板状态 |
|---|---|---|
| **配对 (Paired)** | 双方交换链路密钥、建立信任 —— 蓝牙连接的基础 | ✅ 已完成 |
| 连接 (Connected) | 在配对基础上运行具体**业务**（传文件/放音乐/串口透传） | 板子未实现蓝牙 profile，所以手机显示"已配对" |

**关卡要求「手机蓝牙连开发板」= 配对成功即达标。**
若要手机显示"已连接"，需在板子上实现蓝牙服务（如 SPP 串口透传 / A2DP 音频），属额外工程。

---

## 硬件事实

| 项目 | 值 | 来源 |
|---|---|---|
| 蓝牙芯片 | RTL8723DS 的 BT 半边（与 WiFi 同芯二合一） | SDIO ID + 原理图 U11 |
| BT UART | **UART1 = ttyS1**，PG6(TX)/PG7(RX)，PG8(RTS)/PG9(CTS) | 原理图第1页引脚 1-4 |
| 协议 | H5（Three-wire），115200-8N1 | Readme + 实测 |
| 固件 | `/lib/firmware/rtlbt/rtl8723d_fw`（58,800 B），**config 文件必须移除** | 实测 |
| BT 电源 | rfkill0 = sunxi-bt | dmesg + /sys/class/rfkill |
| BD 地址 | 34:75:63:48:4A:AD | hciconfig |
| 唤醒脚 | bt_wake=PB5 / bt_hostwake=PB4（原理图打叉，悬空） | 原理图 |

---

## 工具清单（板上）

| 工具 | 用途 |
|---|---|
| `rtk_hciattach` | Realtek H5 初始化 + 固件下载（静态交叉编译版，见 patches/） |
| `btmgmt` | 免密配对/可绑定/可发现配置（**关键工具**） |
| `hciconfig` | 适配器状态/名字/类别/可发现 |
| `btmon` | HCI 层抓包（**排障神器**，能看到配对握手全过程） |
| `bluetoothd` | 蓝牙守护进程（提供 SDP 服务记录，手机友好） |

---

## 复刻自检清单

- [ ] 我知道蓝牙走 **UART1 (ttyS1) + H5 协议**
- [ ] 我知道 **config 文件必须移除**（否则 4.9M 波特导致下载超时）
- [ ] 我知道**芯片假死只能靠整机断电**救
- [ ] 我知道 **`bondable`** 不开会"已拒绝配对"
- [ ] 我知道 **class 不设**安卓会隐藏设备
- [ ] 我知道 **io-cap=3** 才能免密配对
- [ ] 我跑通了 `/root/bt_up.sh`，hci0 成功创建
- [ ] 我完成了**手机或电脑的蓝牙配对**

---

*文档版本：v2.1（已完成） ｜ 2026-10-13 ｜ 验证：手机 + 电脑双配对成功 + SPP 蓝牙串口业务实测双向通信通过*

---

## 附录 A：蓝牙「业务」——SPP 蓝牙串口（已实测通过 ✅ 2026-10-13）

**一句话**：板子对外提供一个「蓝牙串口」服务；电脑/手机连上后，板子先问好，然后**你发什么它回什么**。
这就是导师要的「业务」——不是只配对成功，而是真的在传数据。

实测记录（电脑端）：

```
BOARD > *** T113-KelpBar BT SPP connected ***
BOARD > T113: echo server ready, send any line
PC    > HELLO_FROM_WINDOWS_PC
BOARD > T113-Echo: HELLO_FROM_WINDOWS_PC
=== SPP BIDIRECTIONAL BUSINESS VERIFIED (PC -> board -> PC) ===
```

板子端同时记录（`/tmp/spp_events.log`）：

```
=== spp_demo2 start ... dev=/dev/rfcomm1 ch=3 ===
CONNECTED ...
RX: HELLO_FROM_WINDOWS_PC
DISCONNECTED ...
```

---

### A0. 前置条件（每一条都要成立）

| 条件 | 怎么查 | 期望结果 |
|---|---|---|
| hci0 起来了 | `hciconfig hci0` | `UP RUNNING PSCAN ISCAN`，BD Address `34:75:63:48:4A:AD` |
| 设备类别已设 | `hciconfig hci0` 里的 `Class` | `0x000104`（不设的话安卓/Windows 搜不到） |
| bluetoothd 带 -C 在跑 | `ps w \| grep bluetoothd` | 有 `bluetoothd -n -C` |
| SDP 里有串口服务 | `sdptool browse local` | 出现 `Serial Port` + `Channel: 3` |
| 服务在监听 | `cat /tmp/spp_events.log` | 有 `spp_demo2 start ... ch=3` |

---

### A1. 板子端：手动跑一遍

```sh
# 第 1 步：把蓝牙拉起来（固件下载 + 免密可配对 + 注册 SPP 通道3）
sh /root/bt_up.sh

# 第 2 步：起 SPP 串口服务
#   auto = 自己挑一个没被占用的 /dev/rfcommN（原因见 A5-1）
#   3    = 监听通道 3（要和 sdptool 注册的一致）
sh /root/spp_demo2.sh auto 3 &
```

看到 `/tmp/spp_events.log` 里出现 `spp_demo2 start ... dev=/dev/rfcommN ch=3` 就是**待命中**，等对方来连。

> 注意：`sh /root/spp_demo2.sh auto 3` 会一直前台跑（这是正常的，它在等连接）。
> 嫌占终端就 `sh /root/spp_demo2.sh auto 3 > /tmp/spp_boot.log 2>&1 &` 丢后台。

---

### A2. 电脑端连接（Windows）

**先找到「出方向」的串口**。Windows 跟板子配对后会自动建两个蓝牙串口，一个进一个出：

```powershell
Get-PnpDevice -Class Ports | Where-Object { $_.InstanceId -like '*BTHENUM*' } |
    Select-Object FriendlyName, InstanceId | Format-List
```

- `InstanceId` 里带 `_LOCALMFG&0000` 的 = **本机自己的入口，别用**
- `InstanceId` 里带 `347563484AAD` 的（就是板子蓝牙地址）= **连到板子的出口，用这个**

实测这台电脑是：入口 COM8、出口 **COM9**。

**方式一（推荐）：跑现成脚本** `patches/spp_pc_test.ps1`

```powershell
powershell -ExecutionPolicy Bypass -File "D:\t113_work\spp_pc_test.ps1"
```

出现 `=== SPP BIDIRECTIONAL BUSINESS VERIFIED (PC -> board -> PC) ===` 就成功了。

**方式二：随便一个串口工具**
PuTTY / 串口调试助手 → 打开 COM9 → **115200 8N1** → 发送 `HELLO`，应收到 `T113-Echo: HELLO`。

---

### A3. 手机端连接

装任意「蓝牙串口终端」App（例如 Serial Bluetooth Terminal / SPP Terminal）→
连接 `T113-KelpBar` → 应立刻看到两行问候 → 发一行，收到 `T113-Echo: 你发的内容`。

---

### A4. 开机自启（已经配好，重启不用敲命令）

`/etc/rc.local` 末尾已写好两段：

```sh
BTUP=/etc/bt_up.sh
[ -x "$BTUP" ] || BTUP=/root/bt_up.sh
[ -x "$BTUP" ] && sh "$BTUP" > /tmp/bt_boot.log 2>&1 &

SPPD=/etc/spp_demo2.sh
[ -x "$SPPD" ] || SPPD=/root/spp_demo2.sh
if [ -x "$SPPD" ]; then
    rm -f /var/run/spp.pid
    start-stop-daemon -S -b -m -p /var/run/spp.pid -x /bin/sh -- "$SPPD" auto 3
fi
```

**自检方法**：重启板子 → 等 30 秒 → `cat /tmp/spp_events.log` 应看到 `spp_demo2 start ...`；
`hciconfig hci0` 应是 `UP RUNNING PSCAN ISCAN`。都对了就直接从电脑/手机连。

---

### A5. 本次踩到的坑（按踩的顺序，一个都别跳）

1. **`Can't create RFCOMM TTY: Address already in use`**
   元凶：被 `kill` 过的 `rfcomm` 进程会在**内核里留下 dev 占位**（蓝屏一样清不掉）。
   判断：`ls /sys/class/tty | grep rfcomm`，如果出现 `rfcomm0` 而你并没有在用，就是被占了。
   解法：① 用 `auto` 参数自动跳过被占用的编号（本脚本已默认这么做）；② 彻底清空要**重启板子**（内核态只在内存里，重烧/重启即恢复）。
   **反面教材**：不要 `rm /dev/rfcomm0`——节点删了内核里的 dev 还在，只会更乱。

2. **BlueZ 的 `rfcomm listen <dev> <ch> <cmd>` 钩子在本板不执行 cmd**
   所以不能指望它连上后自动跑问候脚本，改用**两段式**：`rfcomm` 负责把 tty 建出来，另一个循环发现 tty 后收发。

3. **板子上没有 `stty` 命令**
   关 tty 回显只能用 `rfcomm` 自带的 `-r`（`--raw`）。不加的话，对方发的字节会被原样弹回去（还带 `^J` 这种控制符）。

4. **`start-stop-daemon -S` 见到残留 pidfile 会拒绝启动**（报 `/bin/sh is already running`）
   → 启动前先 `rm -f /var/run/spp.pid`。

5. **`sdptool` 报 `Failed to connect to SDP server on FF:FF:FF:00:00:00`**
   → `bluetoothd` 必须以 `-C`（compat 兼容模式）启动，否则 `/var/run/sdp` 这个 socket 不生成。

6. **SDP 记录只存在 bluetoothd 的内存里**
   → **每次开机都要重新 `sdptool add --channel=3 SP`**（已写进 `bt_up.sh`）。

7. **Windows 的「出方向」COM 口是「配对那一刻」按 SDP 记录建的**
   如果配对之后通道变了（我们中途从通道 1 换到通道 3），那个口就废了：表现为 `WriteLine 写入超时` 或 `WSAENETUNREACH(0x80072743)`。
   → 解决办法：**删掉这个设备的配对，重新配对一次**。

8. **adb 会话里 `&` 起的进程会随会话结束被杀**
   → 板上要长期跑的服务，用 `start-stop-daemon -S -b` 脱离会话（`-b` = background）。

---

### A6. 文件清单（复刻照着摆）

| 文件 | 放到板子哪里 | 作用 |
|---|---|---|
| `patches/bt_up.sh` | `/root/bt_up.sh` 和 `/etc/bt_up.sh` | 一键起蓝牙：固件下载 + bluetoothd -C + 可发现/免密配对 + 注册 SPP 通道3 |
| `patches/spp_demo2.sh` | `/root/spp_demo2.sh` 和 `/etc/spp_demo2.sh` | SPP 串口服务：问候 + 回显 |
| `patches/rc_local_new4.sh` | `/etc/rc.local` | 开机自启（音频/喇叭/彩条/蓝牙/SPP 全在里面） |
| `patches/spp_pc_test.ps1` | Windows 任意目录 | 电脑端验证脚本（打印双向通信证据） |

烧进固件（重烧不丢）的位置：把前三个文件复制到 SDK 的
`openwrt/target/t113/t113-evb1_auto_nand/base-files/etc/` 下（名字分别是 `bt_up.sh`、`spp_demo2.sh`、`rc.local`），再 `pack`。

---

*文档版本：v2.3（全部完成） ｜ 2026-10-14 ｜ 手机 A2DP 连接成功：媒体音频开关+使用中(SBC)+AUTH ENCRYPT 全链路打通；问题档案见 蓝牙-11~14*

---

## 附录 B：为什么手机不显示「已连接」？（★ 导师一定会问）

### B0. 先说结论

「已配对」和「已连接」是两件不同的事：

| | 含义 | 触发条件 |
|---|---|---|
| **已配对** | 双方交换并保存了密钥（建立信任） | 配对成功 |
| **已连接** | 有 **profile（服务）** 真的连上了 | 音频/输入类 profile 连上才会显示 |

**关键事实：安卓系统的蓝牙设置界面，只对「音频类 / 输入类」profile 显示"已连接"。**
串口（SPP）不在安卓的设置界面里体现——**这不代表没连上**，数据是真的在传（我们有实测证据，见附录 A）。

所以「手机显示已连接」的正路不是串口，而是**蓝牙音箱（A2DP Sink）**。

### B1. A2DP Sink（板子当蓝牙音箱）—— 让手机显示「已连接」

板子上 `bluealsa` 已经跑着（`bt_up.sh` 第 5 步自动启动），SDP 里已有 `Audio Sink` + `AVRCP` 记录。

**手机操作（三步）**：
1. 设置 → 蓝牙 → 确认 `T113-KelpBar` 已配对
2. 点它旁边的 **齿轮/设置图标** → 打开「**媒体音频**（Media audio）」
3. 返回列表 → 设备下面就会显示「**已连接**」

> 如果没有「媒体音频」这个开关：**删掉配对重新配一次**（SDP 记录是配对那一刻缓存的，通道/服务变过就要重配）。

**重要**：显示「已连接」**不需要接喇叭**。喇叭只影响"能不能听到声音"，不影响"连上没连上"。
（想听声音才要把 CN2 喇叭座接上，LM4871 功放使能已由 rc.local 拉低打开。）

**电脑（Windows）同理**：配对后 设置 → 蓝牙 里也会显示「已连接」；把 `T113-KelpBar` 选成声音输出设备即可往里放歌。

### B1.5 ★ 手机"有媒体音频开关、但只是已保存、连不上"怎么办

板上 `bluetoothd` 日志会明说是这个原因：

```
Endpoint registered: /org/bluez/hci0/A2DP/SBC/sink/1      ← 音箱服务本身没问题
Authentication attempt without agent
Access denied: org.bluez.Error.Rejected                   ← 被拒
Browsing: Refusing unexpected connect
```

**原因**：板子上没有配对 agent。手机来连接时 bluetoothd 要找人确认这次鉴权，没人 = 直接拒。
**音频(A2DP)必须鉴权**，所以被拒；而串口(SPP)因为 rfcomm 监听没要求鉴权，所以之前照样能连——
这就是"串口能用、音频连不上"的根源。

**根因还有一层**：板子的配对记录目录 `/var/lib/bluetooth/` 不存在，
说明之前那次配对是 `btmgmt` 在内核层做的（密钥只在芯片里），bluetoothd 根本不知道，
重新下载固件后连芯片里的也没了。**所以手机必须重新配对一次**，让密钥经 bluetoothd 落到
`/var/lib/bluetooth/`（在 overlay 可写分区上，重启不丢）。

**修复（板上）**：`bt_agent.sh` 已随开机自启（`bt_up.sh` 第 3 步），它做的就是：

```sh
{ printf 'agent NoInputNoOutput\ndefault-agent\npairable on\ndiscoverable on\n'; \
  while true; do sleep 3600; done; } | bluetoothctl
```

（那两句 `sleep` 是为了占住管道读端——bluetoothctl 一退出，agent 注册就没了。）

**手机侧操作**：忘记/取消配对 `T113-KelpBar` → 重新搜索并配对（不用输配对码，秒配）
→ 打开「媒体音频」→ 这次应显示「已连接」→ 放歌。

### B2. 板上这条通路的进程

```sh
bluealsa -p a2dp-sink --a2dp-volume -i hci0              # 提供 A2DP 接收端(注册 SDP)
bluealsa-aplay --profile-a2dp 00:00:00:00:00:00          # 把收到的音频送进声卡(00:00.. = 任意设备)
```

查状态：`ps w | grep bluealsa`；两个都在 = 通路就绪。
