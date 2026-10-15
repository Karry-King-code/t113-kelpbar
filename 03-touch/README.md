# 考核③ 触摸：GT9xx 手按屏幕打印坐标 —— 复刻手册

> **目标**：手指按屏幕，系统打印出触摸坐标事件。
> **已验证**：文中命令/路径/输出均在真机核实（2026-10-08）。
> **前置**：考核① 串口、考核② LED+按键 已完成。

---

## 第 0 部分：开工前准备

| # | 需要什么 | 怎么确认 |
|---|---|---|
| 1 | 板子能连 adb | `D:\t113_work\flash_tools\adb.exe devices` → `20080411  device` |
| 2 | VM 能连上，SDK 在 | VM 里 `ls ~/T113-Tina5.0-V1.2` |
| 3 | **知道三个终端的区别** | 见下方速查表 |

### ★ 三窗口速查表

| 终端 | 提示符 | 干什么 |
|---|---|---|
| **VM 终端** | `karry@karry-VirtualBox:~$` | 改代码、编译、打包 |
| **Windows 终端** | `C:\Users\XYT>` | adb、scp |
| **板子终端** | `root@TinaLinux:/#` | 看板子状态 |

> **血泪教训**：有人把板子命令敲进 VM 终端，输出全是虚拟机的设备，以为板子坏了。**敲命令前先看提示符。**

---

## 第 1 部分：硬件事实（★ 这关最反直觉的地方）

### 事实表（三重实证：原理图 + 内核C表 + 上板验证）

| 项目 | 值 | 来源 |
|---|---|---|
| 触摸芯片 | **GT9xx** | 内核 probe 日志 |
| I2C 总线 | **TWI1** | 原理图第7页 FPC 座 |
| I2C 地址 | **0x5D** | 内核 `gt9xxnew_ts 1-005d` |
| 数据脚 | **PE0 (SCL) / PE1 (SDA)** | 原理图 TP_SCK/TP_SDA |
| 中断脚 | **PE5 (TP_INT)** | 原理图 |
| 复位脚 | **PE4 (TP_RST)** | 原理图 |
| 输入设备 | `/dev/input/event5` | `/proc/bus/input/devices` |

> ### ⚠️ 重大更正
> **早期记录写的 `GT9xx@i2c2(0x5D/0x14)` 是错的。**
> 实证结论是 **TWI1**。
> **评估板方案里触摸配在 twi2** —— 直接抄配置就会走一大圈弯路。

### ⭐ 三条认知金句（这关的精华）

| 金句 | 含义 | 这次踩的坑 |
|---|---|---|
| **枚举 ≠ 应答** | 设备树里声明了 i2c 客户端，节点就一定存在；但芯片是否真的应答，要靠 probe 时实际通信 | 之前看到 `2-0014` 设备存在，以为芯片找到了，其实它**从未应答**，是 dts 的"魔法假象" |
| **控制器对 ≠ 线对** | 总线号对了 ≠ 引脚对了 | TWI1 控制器开对了，但引脚配在 PE14/PE15（板级默认），实际线在 PE0/PE1 → 满屏 NACK |
| **能力 ≠ 接线** | 芯片某引脚"支持"某功能 ≠ 板子上就接在那 | 内核 C 表说 PE14/PE15 也能做 TWI1（**芯片能力**），但原理图上根本没接（**实际接线**） |

---

## 第 2 部分：诊断 —— 三个坑，三次手术

### 手术一：幽灵节点遮蔽（"ctp is not used"）

**症状**：串口日志报

```
ctp is not used
script_get_item_err: [ctp_used] get item failed
```

**在哪看**：VM 终端，搜串口日志
```sh
grep -iE "ctp|gt9xx|script_get_item" serial.log | head -20
```

**真因**（★ 关键源码）：

驱动读配置的地方在 `drivers/input/init-input.c` 的 `sunxi_ctp_startup()`：

```c
/* 注意：是从设备树读，不是从 sys_config.fex 读！ */
of_property_read_u32(np, "ctp_twi_id", &...);
```

找节点的函数是：

```c
of_find_node_by_name(NULL, "ctp");
```

> ### ★ 关键理解
> `of_find_node_by_name(NULL, "ctp")` 会**遍历整棵设备树**，
> 返回**第一个**名字是 `ctp` 的节点（只匹配 `@` 前面的部分，忽略 `@14` 之类）。
>
> 如果第一个找到的节点 `status` 不是 `okay`，就报 `ctp is not used`，
> **后面的正确节点永远不会被看到。**

**我当时的情况**：`twi0`（disabled）底下藏着一个旧的 `ctp@14`，它在 `twi2` 之前被搜到 → 挡道。

> **另一个坑**：`gt9xx.c` 里有句打印
> `please put sys_config.fex ctp_used set to 1`
> —— **这是过时提示语**，会把人带偏到改 `.fex` 文件。**别信它，去读 dts。**

**修改**（用 Python 脚本，**不要用 sed**）：

```python
# 在 VM 里执行，删除 twi0 下的挡道 ctp 节点
```

脚本见 `patches/fix_touch_dts.py`。

**验证**：
```sh
grep -c "ctp@" ~/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand/linux-5.4/board.dts
# 期望：1（只剩正确的那个）
```

---

### 手术二：引脚配错了（满屏 NACK）

**症状**：日志满屏

```
SLA+W ... ACK not received
GTP i2c test failed time 1-5
```

**诊断**：上面这些说明**总线通了、芯片找到了、但波形发到了空脚上**，没人应答。

**真因**：

```
board.dts 里 twi1_pins_a / twi1_pins_b 的 pins = "PE14", "PE15"   ← 板级包默认
但原理图上：TP_SCL → PE0，TP_SDA → PE1                            ← 实际接线
```

**核实原理图**（第 7 页，触摸 FPC 座 8 脚）：

| FPC 脚 | 网络 | 对应主控脚 | 用途 |
|---|---|---|---|
| — | TP_SCK | **PE0** | I2C 时钟 |
| — | TP_SDA | **PE1** | I2C 数据 |
| **PE5** | TP_INT | PE5 | 中断 |
| **PE4** | TP_RST | PE4 | 复位 |

**核实内核 C 表**（最高权威）：

```sh
# C 表引脚名是宏写法 PINCTRL_PIN(组, 脚)，搜 "PE0" 搜不到
grep -n -A8 'PINCTRL_PIN(E, 0)' ~/T113-Tina5.0-V1.2/kernel/linux-5.4/drivers/pinctrl/sunxi/pinctrl-sun8iw20.c   # 0x4 = "twi1" /* SCK */
grep -n -A8 'PINCTRL_PIN(E, 1)' ~/T113-Tina5.0-V1.2/kernel/linux-5.4/drivers/pinctrl/sunxi/pinctrl-sun8iw20.c   # 0x4 = "twi1" /* SDA */
```

看到 PE0/PE1 的 **function 4 = "twi1"**（SCK/SDA）。

**修改**：

```
twi1_pins_a / twi1_pins_b 的 pins: "PE14","PE15"  →  "PE0","PE1"
```

脚本见 `patches/fix_twi1_pins.py`（用 Python **锚定块内替换**，防止误伤其他引脚组）。

---

### 手术三：PE12 引脚冲突

**症状**：

```
pin PE12 already requested by 2502800.twi
```

**真因**：`board.dts` 里

```dts
usb_id_gpio    = <&pio PE 12 ...>;
usb_det_vbus_gpio = <&pio PE 12 ...>;
```

而 **twi2** 也想占 PE12 → 冲突。

**修改**：把 twi2 设回 `disabled`（我们不用 twi2）→ 冲突自动消失。

> **一石二鸟**：twi2 本来就是错的方案，关掉它同时解决了引脚冲突。

---

## 第 3 部分：完整的正确配置

### twi1 节点

```dts
&twi1 {
	clock-frequency = <400000>;
	pinctrl-0 = <&twi1_pins_a>;
	pinctrl-1 = <&twi1_pins_b>;
	twi_drv_used = <1>;
	status = "okay";                    // ← 启用
};
```

### twi1 引脚（改过的）

```dts
twi1_pins_a: twi1@0 {
	pins = "PE0", "PE1";                // ← 原来是 "PE14","PE15"
	function = "twi1";
};
```

### ctp 节点（挂在 twi1 下）

```dts
&twi1 {
	ctp@5d {
		compatible = "allwinner,goodix";
		reg = <0x5d>;                   // I2C 地址
		ctp_twi_id = <0x1>;             // ★ 1 = TWI1
		ctp_twi_addr = <0x5d>;
		ctp_screen_max_x = <0x2D0>;     // 720
		ctp_screen_max_y = <0x2D0>;     // 720
		ctp_int_port = <&pio PE 5 ...>; // 中断脚
		ctp_wakeup  = <&pio PE 4 ...>;  // 复位脚
		status = "okay";
	};
};
```

> **注意**：`ctp_screen_max_x/y` 是 **720×720**（十六进制 `0x2D0`）。
> 上板实测 Y 最大值 629 < 720，反向证实这个值是合理的。

---

## 第 4 部分：编译烧录

**VM 终端**：

```sh
cd ~/T113-Tina5.0-V1.2
./build.sh
source build/envsetup.sh
pack
```

**镜像产物**：

```sh
ls -la out/t113_linux_evb1_auto_nand_uart0.img
```

**拉回 Windows**（Windows cmd）：

```cmd
scp -P 2222 karry@127.0.0.1:/home/karry/T113-Tina5.0-V1.2/out/t113_linux_evb1_auto_nand_uart0.img D:\t113_work\t113_touch_twi1_PE01.img
```

**烧录**（你操作）：
1. PhoenixSuit → 选固件
2. 板子断电
3. 按住 **LOAD** 不放
4. 插 DEBUG USB 线
5. 叮咚后数 3 秒松手

---

## 第 5 部分：验证（四关）

| 关 | 怎么验证 | 期望 |
|---|---|---|
| 1 芯片通信 | 串口日志 | `twi1 ... probe success`，**无** NACK |
| 2 驱动 probe | 串口日志 | `gt9xxnew_ts 1-005d`，`input: gt9xxnew_ts as /devices/.../input5` |
| 3 设备注册 | `adb shell "cat /proc/bus/input/devices"` | 见 `N: Name="gt9xxnew_ts"` + `H: Handlers=kbd event5` |
| 4 **事件上报** | `adb shell "hexdump -C /dev/input/event5"` | **手按屏幕，刷出二进制事件流** |

### 怎么看 hexdump 输出（16 字节 = 1 个事件）

```
03 00 35 00 a8 00 00 00     ← X 坐标
│  │  │  │  └──┴─ value = 0x00a8 = 168
│  │  └──┴─ code = 0x0035 (ABS_X)
└──┴─ type = 0x0003 (EV_ABS 坐标事件)
```

**字段对照**：

| type | 含义 |
|---|---|
| `03 00` | EV_ABS —— 坐标事件 |
| `01 00` | EV_KEY —— 按键事件（按下/抬起） |
| `00 00` | EV_SYN —— 一帧结束 |

| code | 含义 |
|---|---|
| `35 00` | ABS_X |
| `36 00` | ABS_Y |
| `4a 01` | BTN_TOUCH（触点） |

**实测样例**（按下屏幕）：

```
01 00 4a 01 01 00 00 00    ← BTN_TOUCH = 1（按下）
03 00 35 00 a8 00 00 00    ← X = 0xa8 = 168
03 00 36 00 1d 02 00 00    ← Y = 0x21d = 541
```

> **value 是小端序**：`a8 00` = 0x00a8 = 168。

---

## 第 6 部分：踩坑档案

| # | 症状 | 真因 | 解法 |
|---|---|---|---|
| 1 | `ctp is not used` | twi0 下幽灵 ctp 节点遮蔽 | 删掉它 |
| 2 | `please set sys_config.fex ctp_used` | **过时提示语**，会带偏 | 忽略，去读 dts |
| 3 | `NACK ×5` / `ACK not received` | 波形出在 PE14/PE15（板级默认），线在 PE0/PE1 | 改 pin 配置 |
| 4 | `pin PE12 already requested` | twi2 与 usb_id_gpio 抢脚 | twi2 设 disabled |
| 5 | `/dev/input/event2` 不停吐乱码 | **那不是触摸**！是评估板残留的电阻触摸（sunxi-ts）空抖 | 认设备靠 **Name 匹配**，不靠"谁在动" |
| 6 | 串口突然全无输出 | COM 口号变了（从 COM4 变 COM7） | 检查设备管理器，重连串口 |
| 7 | `pin PE4 already requested by pio ... csi` | CSI 摄像头也想占 PE4 | **触摸正当赢**（PE4=TP_RST），板子没接摄像头，无影响 |

> ### ⭐ 第 5 项是最重要的一课
> **认设备要认名字，不要认"谁在动"。**
> 一个假设备恰好在吐数据，会让你误以为找对了 —— 这是嵌入式调试最常见的错觉。

---

## 第 7 部分：常考问题

**Q1：触摸为什么用 I2C 不用 SPI？**
A：由**芯片决定**。GT9xx 本身就是 I2C 接口芯片，原理图上只引出 SCL/SDA/INT/RST 四线，没有 SPI 的 MOSI/CS。数据量小 + 400kHz 够用 + 省引脚，所以选 I2C。**屏本身走 MIPI DSI，跟触摸是两条独立通道。**

**Q2：地址是 0x5D 还是 0x14？**
A：**0x5D**。板上应答实证。地址由 `reg = <0x5d>` 声明，由 dts 决定（`USE_DETECT=0` 时不走自动探测）。

**Q3：为什么要改 twi1 的引脚？**
A：因为**控制器对了不代表线对了**。板级包默认把 TWI1 配在 PE14/PE15（芯片支持的第二组引脚），但本板实际接线在 PE0/PE1。改完才能通信。

**Q4：怎么确认引脚该配在哪？**
A：**原理图为准**（第7页 FPC 座），**内核 C 表为权威**（`pinctrl-sun8iw20.c` 里 PE0/PE1 的 function 4 = twi1）。两者交叉验证。

**Q5：`of_find_node_by_name` 为什么会找错节点？**
A：它返回**整棵设备树里第一个**名字匹配的节点（忽略 `@` 后缀）。如果 disabled 的旧节点排在前面，就会命中错误的那个。

---

## 附录A：文件路径

### VM 里

| 用途 | 路径 |
|---|---|
| 设备树真身 | `~/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand/linux-5.4/board.dts` |
| 内核引脚 C 表 | `~/T113-Tina5.0-V1.2/kernel/linux-5.4/drivers/pinctrl/sunxi/pinctrl-sun8iw20.c` |
| 触摸驱动源码 | `~/T113-Tina5.0-V1.2/kernel/linux-5.4/drivers/input/touchscreen/gt9xxnew/` |
| 驱动配置读取 | `~/T113-Tina5.0-V1.2/kernel/linux-5.4/drivers/input/init-input.c` |
| 镜像产物 | `~/T113-Tina5.0-V1.2/out/t113_linux_evb1_auto_nand_uart0.img` |

### 板子里

| 用途 | 路径 |
|---|---|
| 输入设备列表 | `/proc/bus/input/devices` |
| 触摸事件流 | `/dev/input/event5` |
| I2C 设备列表 | `/sys/bus/i2c/devices/` |
| 触摸驱动 | `/sys/bus/i2c/drivers/gt9xxnew_ts` |

### Windows

| 用途 | 路径 |
|---|---|
| adb | `D:\t113_work\flash_tools\adb.exe` |
| 成品镜像 | `D:\t113_work\t113_touch_twi1_PE01.img`（21,550,080 字节） |
| 原理图 | `D:\t113_work\kelpbar_docs\SCH_Schematic_2026-09-24.pdf`（第 7 页 FPC 座） |

---

## 附录B：复刻自检清单

- [ ] 我知道触摸挂 **TWI1**，**不是** twi2
- [ ] 我知道数据脚是 **PE0/PE1**，**不是** PE14/PE15
- [ ] 我能解释 `of_find_node_by_name` 为什么会找错节点
- [ ] 我删掉了 twi0 下的幽灵 ctp 节点
- [ ] 我改了 twi1 的 pins
- [ ] 我把 twi2 设回 disabled
- [ ] 我在 `/proc/bus/input/devices` 里用 **Name** 找到了触摸设备
- [ ] 我能读懂 hexdump 的 16 字节结构
- [ ] 我手按屏幕看到了坐标变化

**全部打勾 = 你独立复刻成功。**

---

*文档版本：v2.0 ｜ 2026-10-08 盖章 ｜ 对应镜像 t113_touch_twi1_PE01.img*
