# 考核⑧ 蓝牙：手机/电脑连接开发板 ✅ 已完成

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

**考核要求「手机蓝牙连开发板」= 配对成功即达标。**
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

*文档版本：v2.0（已完成） ｜ 2026-10-12 ｜ 验证：手机 + 电脑双配对成功*


---

## 附录：蓝牙「业务」服务（手机显示已连接的关键）

配对只是建立信任；要让手机显示**已连接**并真的用起来，板子需要提供**蓝牙服务（profile）**。

### 服务一：A2DP Sink（蓝牙音箱）★ 推荐

让板子变成蓝牙音箱 —— 手机连上后放音乐从板子喇叭出。



**注册后的 SDP 记录**（ 验证）：


**手机操作**：蓝牙设置 → 点  旁的设置图标 → 打开「**媒体音频**」→ 手机自动连接并显示**已连接**。

### 服务二：SPP（蓝牙串口）

板子提供蓝牙串口，收到什么回显什么。



**提示**： 必须以 **（compat）** 启动，否则  socket 不存在，sdptool 报错
。

### 完整服务启动（含业务）


