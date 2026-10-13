# 考核⑧ 蓝牙：手机蓝牙连接开发板

## 状态：🔧 攻坚中（最后卡点：固件补丁下载超时）

### 已验证的三条路径（全部实测）
| 路径 | 结果 |
|---|---|
| rtk_hciattach v3.1 用户态下载（官方 fw 对 + 无 config） | H5 建链✓ → patch 超时 ✗ |
| 内核 ldisc 路径（stock hciattach 3wire） | "setup complete" 但 hci0 未注册 ✗ |
| config 有无 / fw 版本 / 流控 / WiFi 开关 | 全部变量矩阵已试，同失败 |

### 下一步（需要新会话 + 逻辑分析仪或内核调试）
1. 逻辑分析仪抓 PG6/PG7 波形，确认芯片到底应答到哪一步
2. 找同 SDK 版本其他板子的原版 rtk_hciattach 二进制直接跑
3. 深入 5.4 内核 hci_h5.c serdev 探测路径调试

---

## 已确认的硬件/软件事实（全部实测）

| 项目 | 值 | 证据 |
|---|---|---|
| 蓝牙归属 | RTL8723DS 二合一芯片的 BT 半边（WiFi 同芯） | SDIO ID + 原理图 U11 |
| BT UART | **UART1 = ttyS1，PG6(TX)/PG7(RX)**（RTS/CTS=PG8/PG9） | 原理图第1页引脚1-4 + 区域标注 WIFI+BT |
| 唤醒脚 | bt_wake=PB5 / bt_hostwake=PB4 —— **原理图打叉（悬空）** | 原理图 PB 组 |
| BT 电源开关 | rfkill0 = sunxi-bt（dts bt@0 节点创建，`echo 0/1 > /sys/class/rfkill/rfkill0/state`） | v12 上板实测 |
| 固件 | /lib/firmware/rtlbt/rtl8723d_fw(58KB) + rtl8723d_config(41B)（另有 dsh4 变体） | v12 已含 |
| 内核传输 | H5（Three-wire）协议已编入：`HCI UART protocol Three-wire (H5) registered` | v12 dmesg |
| 用户态工具 | rtk_hciattach v3.1 静态交叉编译版（Realtek 官方源码） | patches/rtk_hciattach |

## 当前进度（真实记录）

```
✅ 芯片响应 SYNC（加电后首测：Get SYNC Resp Pkt / Get SYNC pkt-active mode）
✅ H5 建链完成（Get CONFG resp / H5 init finished）
✗ 固件补丁下载超时（patch timerout, download patch re send 13+ 次）
```

## 已知的坑与推理

| # | 现象 | 推理 |
|---|---|---|
| 1 | 芯片"假死"跨软重启保持 | BT 供电域 = VBAT 常供电，软重启/模块 rmmod 不断 BT 电；**唯一可靠复位 = 整机拔线断电 15 秒** |
| 2 | `&` 后台方式启动 hciattach 会随 adb 会话退出被杀（日志空=进程早死） | 必须用持久会话（run_in_background 的 adb）跑前台命令 |
| 3 | 首次 SYNC 成功后，被杀再重启 hciattach → SYNC 无应答 | 芯片停在 H5 已同步态，需断电复位 |
| 4 | patch 下载超时（sync/config 都 OK 之后） | 候选：config 后芯片启用流控而主机侧不匹配 / config 触发芯片复位后需要重新 SYNC / 需要与固件匹配版本的 rtk_hciattach |

## 下一步候选方案（按优先级）

1. **断电复位后立即 attach**（不插拔 OTG 线；attach 后不关会话不杀进程，一次跑完）
2. 下载**匹配版本**的 rtk_hciattach（SDK 引用的版本缺失；GitHub plow-technologies/rtl8723ds_bt 是 v3.1，可试 lwfinger/rtl8723bs_bt 的更新版）
3. 对比分析 rtl8723d_config 的条目（41 字节）确认芯片 config 后的流控/波特行为
4. 终极方案：交叉编译 bluez 主线 hci_h5 的 serdev 路线需要 dts+内核改动（本内核 hci_h5 匹配表只支持 ACPI）

## 快速复现/测试命令

```sh
# 状态
adb shell "ls /sys/class/bluetooth/; hciconfig"
# 蓝牙电源复位
adb shell "echo 0 > /sys/class/rfkill/rfkill0/state; sleep 1; echo 1 > /sys/class/rfkill/rfkill0/state"
# 初始化（必须持久会话，不能 & 后台后退出）
adb shell "rtk_hciattach -n -s 115200 /dev/ttyS1 rtk_h5"
# 若无响应 → 整机断电 15 秒（拔所有 USB 线）
```

---

*状态截至 2026-10-12：芯片存活+H5建链已实锤，patch 下载最后一环待攻*
