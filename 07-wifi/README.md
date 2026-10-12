# 考核⑦ WiFi：连手机热点 —— 复刻手册

> **目标**：板子通过 WiFi 连上手机热点，并访问互联网。
> **状态**：✅ **已完成**（2026-10-10：wlan0 出现 + 连接热点 + ping 公网 60ms）
> **前置**：考核①（串口）完成

---

## 第 0 部分：本关的特殊性（先看这个）

**这一关的问题不是"调试"，而是"天生装错驱动"。**

你的板子 WiFi 芯片是 **Realtek RTL8723DS**，但固件里装的驱动是**全志自家的 XR829**——
两家公司的芯片协议完全不同，相当于给丰田车装了大众的钥匙。开机日志的报错就是证据：

```
[XRADIO] Detect SDIO card 0        ← 总线发现了芯片
[SBUS_ERR] sdio probe timeout!     ← XR829 驱动跟它"说话"，芯片听不懂
xradio_core_init failed (-110)!
```

**所以这关的工作全部在固件侧**：换正确驱动 → 解决连锁的三个编译/集成问题 → 找到打开开关的机制。

---

## 第 1 部分：诊断过程（完整推理链）

### 第1步：确认"芯片活着"

**在哪**：板子终端
**敲什么**：

```sh
ls /sys/bus/sdio/devices/
cat /sys/bus/sdio/devices/*/vendor
cat /sys/bus/sdio/devices/*/device
```

**我看到的**：

```
mmc1:0001:1
vendor  = 0x024c
device  = 0xd723
```

**查证**：SDIO 设备 ID `024c:d723` = **Realtek RTL8723DS**（Realtek 的官方 SDIO vendor ID 是 0x024c）。
与原理图第 2 页 `U11 = RTL8723DS模块` **完全吻合**。

> **金句：芯片活着，总线能枚举它——问题只能在驱动。**

### 第2步：确认"驱动是错的"

**在哪**：VM 终端
**敲什么**：

```sh
grep -iE 'RTL8723|XR829' ~/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand/linux-5.4/config-5.4
```

**我看到的**：只有 `CONFIG_XR829_WLAN=m`，**没有任何 RTL8723 驱动**。

### 第3步：找正确的驱动（三连跳）

| 尝试 | 结果 | 教训 |
|---|---|---|
| **rtl8821cs 驱动**（内核树里有，含 8723d 头文件） | ❌ 头文件路径断裂：`drv_types.h: No such file` | 它是**裁剪版**（只支持 8821C），且相对路径 `-I$(src)` 在 O= 目录外构建下失效 |
| **rtl8723ds 内置 =y** | ❌ 链接冲突：`multiple definition of aes_encrypt`（与内核 `lib/crypto/aes.o` 撞车） | 自带加密库的驱动**必须编成模块 =m** |
| **rtl8723ds 模块 =m** | ✅ `LD [M] 8723ds.ko` 编译成功 | SDK 自家的 `bsp/drivers/net/wireless/rtl8723ds/` 是完整源码 |

> **为什么 rtl8723ds 能编过而 rtl8821cs 不行？**
> rtl8723ds 是 SDK **原生集成**的驱动（内核 Makefile 第36行 `obj-$(CONFIG_RTL8723DS) += rtl8723ds/` 早就写好），构建系统为它适配过；rtl8821cs 是半残的移植。

### 第4步：让 .ko 进 rootfs —— KernelPackage 机制（★ 本关最大收获）

**问题**：.ko 编出来了，但 rootfs 里没有（`/lib/modules/5.4.61/` 只有 xr829.ko）。

**原因**：OpenWrt 的 rootfs 只装"被选中的包"。内核模块要用 **KernelPackage** 机制声明。

**在哪定义**：`openwrt/openwrt/target/linux/t113-common/modules.mk`（net-xr829、net-broadcom 都在这里，照抄格式）

**我加的定义**：

```
define KernelPackage/net-8723ds
  SUBMENU:=$(WIRELESS_MENU)
  TITLE:=Realtek RTL8723DS SDIO WiFi support
  DEPENDS:= +@IPV6 +kmod-cfg80211
  KCONFIG:=\
	CONFIG_RTL8723DS=m \
	CONFIG_RFKILL=y \
	CONFIG_RFKILL_GPIO=y
  FILES:=$(LINUX_DIR)/drivers/net/wireless/rtl8723ds/8723ds.ko
  AUTOLOAD:=$(call AutoProbe, 8723ds)
endef

define KernelPackage/net-8723ds/description
 Kernel modules for Realtek RTL8723DS SDIO WiFi
endef

$(eval $(call KernelPackage,net-8723ds))
```

**开启包**（`openwrt/target/t113/t113-evb1_auto_nand/defconfig` 加一行）：

```
CONFIG_PACKAGE_kmod-net-8723ds=y
```

**效果**：以后每次 `build.sh` 都自动把 8723ds.ko 装进 rootfs 并生成 `/etc/modules.d/net-8723ds`（开机自动加载）—— **一劳永逸，这才是工程的正确做法。**

> ### ⚠️ 三个配置层的区别（容易改错文件）
> | 文件 | 管什么 |
> |---|---|
> | `device/.../linux-5.4/config-5.4` | 内核配置（CONFIG_RTL8723DS=m 写这里） |
> | `openwrt/target/t113/.../defconfig` | Tina 包选择（PACKAGE_kmod-net-8723ds=y 写这里） |
> | `openwrt/openwrt/target/linux/t113-common/modules.mk` | KernelPackage 定义（驱动↔包的映射写这里） |

---

## 第 2 部分：连热点（含一个中文 SSID 的坑）

### 板子自带傻瓜命令

```sh
wifi -o sta          # 开启客户端模式
wifi -s              # 扫描
wifi -c <名称> <密码> # 连接
```

### ⚠️ 中文 SSID 的坑（实测踩到）

**热点名叫"名称1"，用 `wifi -c 名称1 987654321` 连不上。**

**怎么定位的**：用 wpa_cli 看芯片扫描结果 + hexdump 看原始字节：

```sh
wpa_cli -p /etc/wifi/wpa_supplicant/sockets -iwlan0 scan_results | grep 46:c6:ab | hexdump -C
```

**结果**：那行结尾只有 `31 0a`（就是 "1\n"）—— **手机实际广播的名字只有 "1"**，中文字符被手机丢了。

**解法**：按真实名字连：

```sh
wpa_cli -p /etc/wifi/wpa_supplicant/sockets -iwlan0 set_network 0 ssid '"1"'
wpa_cli -p /etc/wifi/wpa_supplicant/sockets -iwlan0 set_network 0 psk '"987654321"'
wpa_cli -p /etc/wifi/wpa_supplicant/sockets -iwlan0 enable_network 0
```

> **教训**：**别用中文给热点命名**（嵌入式设备 + 各种工具对多字节编码支持参差）。
> 或者：连之前先用 `scan_results` 看**芯片实际广播的名字**，别信你设置的名字。

### wpa_cli 的控制通道（报错 `No such file or directory` 时）

wpa_supplicant 启动时用 `-O` 指定了 socket 目录，wpa_cli 必须对齐：

```sh
wpa_cli -p /etc/wifi/wpa_supplicant/sockets -iwlan0 <命令>
```

### 验证连接成功

```sh
wpa_cli -p /etc/wifi/wpa_supplicant/sockets -iwlan0 status
```

**成功的样子**：

```
bssid=46:c6:ab:55:ba:29
ssid=1
key_mgmt=WPA2-PSK
wpa_state=COMPLETED            ← 关联完成
ip_address=192.168.26.40       ← 自动拿到 IP
```

### 最终验证：ping 公网

```sh
ping -c 3 223.5.5.5
```

**我实测**：3 包全通，延迟约 60ms（走手机流量）。

---

## 第 3 部分：实测数据存档

| 项目 | 值 |
|---|---|
| WiFi 芯片 | RTL8723DS（SDIO，vendor 024c:d723） |
| 驱动 | rtl8723ds v5.10.1-33-g2b795d825.20210322_beta |
| 接口 | wlan0（MAC 34:75:63:29:C6:2D）+ wlan1（P2P用） |
| 连接热点 | ssid="1" WPA2-PSK |
| 板子 IP | 192.168.26.40 |
| 公网延迟 | ~60ms |

## 第 4 部分：踩坑档案

| # | 症状 | 真因 | 解法 |
|---|---|---|---|
| 1 | `sdio probe timeout` / 没有 wlan0 | **驱动品牌错**（XR829 驱 Realtek 芯片） | 换 rtl8723ds |
| 2 | rtl8821cs 驱动编译报 `drv_types.h not found` | **O= 构建下相对 include 路径失效** + 该驱动是裁剪版 | 放弃，用 rtl8723ds |
| 3 | rtl8723ds =y 链接报 `multiple definition of aes_encrypt` | 内置驱动与内核 `lib/crypto` 符号撞车 | 改 **=m 模块** |
| 4 | .ko 编出来但 rootfs 没有 | OpenWrt 只装被选中的包 | **KernelPackage 机制**（见第1部分第4步） |
| 5 | 驱动加载报 `get wifi_sdc_id failed` | **dts 父节点 rfkill@0 是 disabled**，wlan@0 被连坐 | rfkill 改 okay（先确认不抢串口：wlan_pins_a 只用 PG11） |
| 6 | `wifi -c 名称1` 连不上 | **中文 SSID 传输/显示编码问题**；手机实际只广播 "1" | 按 scan_results 的真实字节连接 |
| 7 | wpa_cli 报 `Failed to connect to ctrl_ifname` | socket 目录不对 | 加 `-p /etc/wifi/wpa_supplicant/sockets` |

## 第 5 部分：常考问题

**Q1：怎么知道 WiFi 芯片是什么型号？**
A：三层证据：①原理图第 2 页 U11=RTL8723DS；②SDIO 枚举 ID `024c:d723` 是 Realtek 官方分配的 8723DS 标识；③换上正确驱动后芯片正常工作。**硬件型号以"总线枚举 ID + 原理图"双重确认，不靠猜。**

**Q2：为什么原厂固件装错驱动？**
A：评估板的 WiFi 方案与课程板不同。课程板（小智学长）用的是 RTL8723DS 模块，而 BSP 默认配置按全志参考板（XR829）生成 —— **BSP 移植的本质就是让软件配置匹配实际硬件**。

**Q3：为什么驱动要编成模块不是内置？**
A：rtl8723ds 自带一套加密实现（aes/sha256），与内核 `lib/crypto` 的同名符号在 vmlinux 链接时冲突。编成模块（=m）符号独立，且模块可以单独更新不用重烧系统。

**Q4：rfkill 是什么？为什么要打开它？**
A：rfkill 是内核的无线设备开关框架。这块板的 `wlan@0` 节点挂在 `rfkill@0` 下面，**设备树规则是父节点 disabled 则子节点不加载**。当初为了修串口把它关了（旧 BSP 里它的引脚配置会抢串口），现在确认新配置只用 PG11 不冲突，所以安全打开。

**Q5：怎么证明 WiFi 真的通了？**
A：三层：①`wpa_state=COMPLETED`（链路层关联成功）②`ip_address=192.168.26.40`（网络层拿到 IP）③`ping 223.5.5.5` 全通（传输层真实流量）。

---

## 附录A：关键命令速查

```sh
# 驱动状态
adb shell "dmesg | grep -i RTW | tail"
adb shell "ls /sys/class/net/"

# 扫描周围热点
adb shell "wpa_cli -p /etc/wifi/wpa_supplicant/sockets -iwlan0 scan; sleep 4; wpa_cli -p /etc/wifi/wpa_supplicant/sockets -iwlan0 scan_results"

# 连接（推荐用傻瓜命令，ASCII 名称时）
adb shell "wifi -c <热点名> <密码>"

# 连接状态
adb shell "wpa_cli -p /etc/wifi/wpa_supplicant/sockets -iwlan0 status"

# 联网测试
adb shell "ping -c 3 223.5.5.5"
```

## 附录B：复刻自检清单

- [ ] 我知道芯片是 **RTL8723DS**（SDIO ID 024c:d723 双重确认）
- [ ] 我知道原固件装的是 **XR829 驱动**（品牌错配）
- [ ] 我知道 rtl8723ds 必须 **=m 模块**（=y 符号冲突）
- [ ] 我知道 **KernelPackage 机制**在 `t113-common/modules.mk`
- [ ] 我知道三个配置层的区别
- [ ] 我知道 rfkill 父节点必须 okay
- [ ] 我知道 wpa_cli 要加 `-p` 指定 socket 目录
- [ ] 我知道中文 SSID 的编码坑
- [ ] 我完成了 **ping 公网**

**全部打勾 = 你独立复刻成功。**

---

*文档版本：v1.0 ｜ 2026-10-10 ｜ 已完成：wlan0 + 热点连接 + 公网 ping 60ms*
