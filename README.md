# T113 KelpBar 嵌入式全流程学习（全志 T113-S3）

从零开始，在一块全志 T113-S3 开发板上完成 7 项外设bring-up：
**调试串口 → LED/按键 → 触摸 → 屏幕显示 → 喇叭 → 麦克风 → WiFi**。

每个节点都有一份**小白可无脑跟做**的复刻手册：硬件事实、逐条命令、每步验证、踩坑档案。

---

## 🗺️ 新手从这里开始（按顺序做）

| 顺序 | 节点 | 手册 | 核心技术 |
|---|---|---|---|
| 1 | **debug 串口** ✅ | [01-serial/README.md](01-serial/README.md) | UART3 / PB6,PB7 / 115200-8N1 |
| 2 | **LED + 按键** ✅ | [02-led-key/README.md](02-led-key/README.md) | GPIO 子系统 / PD11,PD10 / evdev |
| 3 | **触摸** ✅ | [03-touch/README.md](03-touch/README.md) | GT9xx / TWI1 / PE0,PE1 / 0x5D |
| 4 | **屏幕显示** ✅ | [04-display/doc/显示-从黑屏到彩条全程教程.md](04-display/doc/显示-从黑屏到彩条全程教程.md) | FL7707N MIPI DSI / 720×1424 |
| 5 | **喇叭** ✅ | [05-speaker/README.md](05-speaker/README.md) | LM4871 功放 / aplay+madplay(MP3) |
| 6 | **麦克风** ✅ | [06-mic/README.md](06-mic/README.md) | 板载驻极体麦 / arecord |
| 7 | **WiFi** ✅ | [07-wifi/README.md](07-wifi/README.md) | RTL8723DS 驱动换装 / wpa_cli |
| 8 | **蓝牙** 🔧 | 09-lvgl 前完成 | RTL8723DS BT / UART1 H5 |
| 9 | **LVGL** ⏸ | 等屏幕配件 | app_sdk_v2 |

> **串口是地基**：所有后续节点的诊断都靠它。请从 1 开始按顺序做。

---

## 📦 你需要准备的东西

| 类别 | 清单 |
|---|---|
| 硬件 | T113 KelpBar 板 × 1、USB-TypeC 线 × 2（调试+OTG）、USB 串口线、喇叭（CN2 座，2P 1.25mm）、可开热点的手机 |
| 软件 | PhoenixSuit（烧录）、串口终端、adb（均在板子配套工具包） |
| 环境 | VirtualBox 虚拟机 + Ubuntu（编译 SDK 用，VM 用户 `karry`），SDK 路径 `~/T113-Tina5.0-V1.2` |

**三个终端别搞混**（新手最高频事故）：

| 终端 | 提示符样子 | 干什么 |
|---|---|---|
| Windows cmd / Git Bash | `C:\Users\xxx>` | adb、scp（命令里带 `adb` 的都在这敲） |
| 虚拟机 Ubuntu | `karry@xxx:~$` | 编译 SDK（`./build.sh`、`pack`） |
| 板子（adb shell 后） | `root@TinaLinux:/#` | 板子上的操作（`cat /proc/...`、`aplay`） |

---

## 📁 仓库结构

```
├── README.md               ← 本文件（入口）
├── 全部问题档案.md          ← ★ 全项目 40+ 个坑的完整记录（症状/真因/解法）
├── 新会话启动提示词.md       ← 给 AI 助手的交接文档
├── 01-serial/              ← 考核① 串口
│   ├── README.md           #    复刻手册
│   ├── doc/                #    详细章节
│   └── patches/            #    修改脚本
├── 02-led-key/ ... 07-wifi/ ← 考核②~⑦（结构同上）
└── push_all.sh             # 仓库推送辅助脚本
```

每个节点的 README 都包含：**硬件事实 → 诊断过程 → 完整配置 → 验证关卡 → 踩坑档案 → 常考问题 → 复刻自检清单**。

---

## 🧭 贯穿全项目的方法论

### 三层定位法 —— 出问题先问「改哪一层」

```
boot0(闭源) → U-Boot(可改/重编) → Kernel+设备树(可改/重编) → rootfs(板上直接改)
```
> rootfs 最省事：不用重编不用烧录。但要知道什么改动必须进内核。

### 排查金句（全部来自真实踩坑，详见[全部问题档案](全部问题档案.md)）

| 金句 | 含义 | 出处 |
|---|---|---|
| 枚举 ≠ 应答 | 设备树声明了设备 ≠ 芯片真的应答 | 触摸 |
| 控制器对 ≠ 线对；能力 ≠ 接线 | 总线号对 ≠ 引脚对；芯片支持 ≠ 板上接了 | 触摸 |
| 谁开屏就改谁 | 黑屏要找到真正开屏的那段代码 | 显示 |
| 名字骗人，去看谁用它 | `lcd_used` 听起来像开关，实际不是 | 显示 |
| 认设备认名字，不认"谁在动" | `/proc/bus/input/devices` 的 Name 字段 | 按键 |
| SHDN 类引脚极性必须查数据手册 | SHUTDOWN 高电平=关断，不是使能 | 喇叭 |
| 命令没报错 ≠ 功能正常 | 录音要分析数据内容 | MIC |
| 内核配置被静默丢弃 = 依赖不满足 | 沿 depends on 挖到底 | WiFi/BT |

### 四条铁律
1. **风险优先** —— 改文件前先备份（`cp 文件 文件.bak`）
2. **信源** —— 参数去规格书/原厂代码抄，不猜
3. **三审** —— ①事实来源 ②逻辑通不通 ③未验证假设
4. **90% 把握才动手**

---

## 🔌 硬件事实总表（全部经原理图+上板双重确认）

| 外设 | 引脚/参数 |
|---|---|
| 调试串口 | UART3，TX=PB6，RX=PB7，115200-8N1 |
| LED1 | PD11（高电平亮） |
| 按键 BTN1 | PD10（按下低电平） |
| 触摸 | GT9xx，TWI1，SCL=PE0，SDA=PE1，INT=PE5，RST=PE4，addr=0x5D |
| 屏幕 | FL7707N，MIPI DSI 4-lane，720×1424，背光 PWM ch7 |
| 喇叭 | HPOUTR → LM4871 功放 → CN2 座；功放使能 PA_SHDN=PB2（低=工作） |
| 麦克风 | 板载 GMI4015P 驻极体（MIC 丝印旁），走 MIC3 差分输入 |
| WiFi/BT | RTL8723DS 二合一：WiFi 走 SDIO（mmc1），BT 走 UART1（PG6/PG7）H5 |

---

## 💾 固件版本记录

| 镜像 | 内容 |
|---|---|
| 基线 | 官方 BSP 串口移植版 |
| v6_bar1424 | 屏幕彩条达成（720×1424） |
| v8_music | + MP3 播放（madplay） |
| v9_ampfix | + 功放极性修复（重要） |
| v11_wifi_rfkill | + RTL8723DS WiFi 驱动 |
| **v12_bt（最新）** | + 蓝牙 H5 驱动/电源管理/初始化脚本适配 |

> 固件体积大不入 git。各节点 patches/ 里有全部源码级修改，可从官方 BSP 重新生成。

---

## 🤖 AI 协作说明

本项目使用 AI 编程助手结对完成。[`新会话启动提示词.md`](新会话启动提示词.md) 是给新会话 AI 的交接文档；
[`全部问题档案.md`](全部问题档案.md) 同时也是 AI 排障知识库。

---

*最后更新：2026-10-12*
