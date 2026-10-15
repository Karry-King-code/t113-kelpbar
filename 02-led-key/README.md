# 考核② LED + 按键：点灯 + 读按键 —— 复刻手册

> **目标**：① LED 能点亮/熄灭 ② 按键能读到按下事件
> **已盖章**：2026-09-30
> **前置**：考核① 串口已完成（能进 shell）

---

## 第 0 部分：开工前准备

| # | 需要什么 | 怎么确认 |
|---|---|---|
| 1 | 串口能进 shell 或 adb 能连 | `adb devices` → `20080411  device` |
| 2 | VM 能连上，SDK 在 | VM 里 `ls ~/T113-Tina5.0-V1.2` |
| 3 | **知道三个终端的区别** | 见下方速查表 |

### ★ 三窗口速查表

| 终端 | 提示符 | 干什么 |
|---|---|---|
| **VM 终端** | `karry@karry-VirtualBox:~$` | 改代码、编译、打包 |
| **Windows 终端** | `C:\Users\XYT>` | adb、scp |
| **板子终端** | `root@TinaLinux:/#` | 看板子状态 |

> **血泪教训**：把板子命令敲进 VM 终端，输出全是虚拟机自己的设备，会让人以为板子坏了。**敲命令前先看提示符。**

---

## 第 1 部分：硬件事实

| 项目 | 引脚 | 方向 | 有效电平 |
|---|---|---|---|
| **LED1** | **PD11** | 输出 | 高电平点亮 |
| **BTN1** | **PD10** | 输入 | 按下为低电平 |

**引脚号换算**（dts 里用的是「组 + 脚」两个数字）：

```
PD11 → &pio  3  11
       │     │  └─ 组内第 11 脚
       │     └──── 组号：A=0, B=1, C=2, D=3
       └────────── pio 控制器

验证：3 × 32 + 11 = 107   ← 这就是 sysfs 里的 pin 107
```

> **怎么确认极性？** 原理图看：
> - LED 是高电平点亮还是低电平点亮（看 LED 是接 VCC 还是 GND）
> - 按键按下时，引脚是被拉到低还是高
>
> **拿不准就先按推测写，实测不对再翻转**（这是正常调试流程，不是失败）。

---

## 第 2 部分：★ 第一步 —— 内核开关（最容易漏的一步）

### 先侦察：这些开关开了没

**在哪**：VM 终端
**敲什么**：

```sh
grep -nE 'GPIO_SYSFS|LEDS_GPIO|GPIO_KEYS|NEW_LEDS|LEDS_CLASS|KEYBOARD_GPIO' \
  ~/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand/linux-5.4/config-5.4
```

**我看到的**：**零输出** = 所有这些开关都没开。

### 需要开 **6 个**开关（不是 3 个！）

> ### ⚠️ 这里有个大坑
> 很多人以为只要开 `LEDS_GPIO` 和 `GPIO_KEYS` 就够了。
> **错。** LED 子系统有**依赖链**，父开关不开，子开关无效：

| 开关 | 作用 | 为什么需要 |
|---|---|---|
| `CONFIG_NEW_LEDS` | LED 子系统框架 | **父开关**，不开则下面无效 |
| `CONFIG_LEDS_CLASS` | LED 类设备 | 中间层 |
| `CONFIG_LEDS_GPIO` | GPIO 控制 LED 的驱动 | **LED 功能本体** |
| `CONFIG_GPIO_SYSFS` | GPIO 的 sysfs 接口 | 用户态操作引脚 |
| `CONFIG_GPIO_KEYS` | 按键的通用子系统 | 按键功能需要 |
| **`CONFIG_KEYBOARD_GPIO`** | **gpio-keys 驱动本体** | ★ **最容易漏的一个** |

> ### ⚠️⚠️ `GPIO_KEYS` vs `KEYBOARD_GPIO` —— 名字陷阱
>
> 这两个名字**长得像，作用完全不同**：
> - `CONFIG_GPIO_KEYS` = 子系统杂项
> - `CONFIG_KEYBOARD_GPIO` = **驱动本体**
>
> **只开前者不开后者 → dts 节点变成"没人认领的孤儿"，按键完全无反应。**
>
> 这个坑当时坑了一整轮：LED 亮了，按键没反应，
> 因为"不对称现象"才锁定到这两个开关的差异。
>
> **★ 排查心法：出现"LED 好但按键不好"这种不对称现象，立刻去对比两者的驱动/开关差异。**

### 怎么开

**在哪**：VM 终端

```sh
cd ~/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand/linux-5.4

# 先备份
cp config-5.4 config-5.4.bak-gpio

# 追加 6 个开关
cat >> config-5.4 << 'EOF'
CONFIG_NEW_LEDS=y
CONFIG_LEDS_CLASS=y
CONFIG_LEDS_GPIO=y
CONFIG_GPIO_SYSFS=y
CONFIG_GPIO_KEYS=y
CONFIG_KEYBOARD_GPIO=y
EOF

# 验证：应该看到 6 行
grep -cE 'CONFIG_NEW_LEDS|CONFIG_LEDS_CLASS|CONFIG_LEDS_GPIO|CONFIG_GPIO_SYSFS|CONFIG_GPIO_KEYS|CONFIG_KEYBOARD_GPIO' config-5.4
```

**期望**：输出 `6`。

---

## 第 3 部分：设备树节点

### ⚠️ 先确认改的是真身

```sh
cd ~/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand
ls -la board.dts        # 第一个字符是 l = 软链接
```

> **`sed -i` 会破坏软链接！**（详见 01-serial 文档的"软链接陷阱"章节）
> **一律改真身 `linux-5.4/board.dts`，或用 Python 脚本。**

### 追加两个节点

**在哪**：VM 终端

```sh
cd ~/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand/linux-5.4

# 备份
cp board.dts board.dts.bak-led

# 追加节点
cat >> board.dts << 'EOF'

/ {
	leds {
		compatible = "gpio-leds";
		led1 {
			label = "kelpbar:led1";
			gpios = <&pio 3 11 GPIO_ACTIVE_HIGH>;
			default-state = "off";
		};
	};

	gpio-keys {
		compatible = "gpio-keys";
		btn1 {
			label = "kelpbar:btn1";
			gpios = <&pio 3 10 GPIO_ACTIVE_LOW>;
			linux,code = <115>;
			wakeup-source;
		};
	};
};
EOF

# 验证：应看到 kelpbar:led1 和 kelpbar:btn1
grep -n "kelpbar" board.dts
```

### 节点逐行解释

```dts
led1 {
	label = "kelpbar:led1";                      // sysfs 里的目录名
	gpios = <&pio 3 11 GPIO_ACTIVE_HIGH>;        // PD11，高电平点亮
	default-state = "off";                       // 开机默认熄灭
};
```

| 字段 | 含义 |
|---|---|
| `compatible = "gpio-leds"` | **自我介绍**：告诉内核"我是 gpio-leds 驱动的设备"，内核靠这个字符串匹配驱动 |
| `label` | sysfs 里的**目录名**（`/sys/class/leds/kelpbar:led1/`） |
| `gpios` | 三段式：`&pio`（控制器）+ `3`（D 组）+ `11`（第11脚）+ 极性 |
| `GPIO_ACTIVE_HIGH` | 高电平 = 点亮 |

```dts
btn1 {
	label = "kelpbar:btn1";
	gpios = <&pio 3 10 GPIO_ACTIVE_LOW>;         // PD10，按下为低
	linux,code = <115>;                          // 键值 115 = KEY_VOLUMEUP
	wakeup-source;                               // 可唤醒系统
};
```

| 字段 | 含义 |
|---|---|
| `linux,code = <115>` | 按键上报的键码。115 = `KEY_VOLUMEUP`（音量加），**随便选的**，只要是个合法键码 |
| `wakeup-source` | 标记为可唤醒源 |

> **为什么按键不用写中断处理代码？**
> `gpio-keys` 驱动**已经内置**了中断处理、去抖、事件上报。
> **你只要在设备树里"登记"一下，驱动自己会干活。** 这是 Linux 驱动的设计哲学。

---

## 第 4 部分：编译 → 打包 → 烧录

**VM 终端**：

```sh
cd ~/T113-Tina5.0-V1.2
./build.sh
source build/envsetup.sh
pack
```

> **这次要真的重编**（改的是内核 config，LED/按键驱动要编译），约 10-20 分钟。
> 看到 `build OK` → `pack finish` 才算成功。

**编译时怎么确认开关生效了**：

```sh
# 检查编译产物的 .config
grep -E 'LEDS_GPIO|KEYBOARD_GPIO' ~/T113-Tina5.0-V1.2/out/t113/kernel/build/.config
```

**期望**：看到 `=y`（不是 `# ... is not set`）。

**镜像**：
```sh
ls -la out/t113_linux_evb1_auto_nand_uart0.img
```

**拉回 Windows**（cmd）：
```cmd
scp -P 2222 karry@127.0.0.1:/home/karry/T113-Tina5.0-V1.2/out/t113_linux_evb1_auto_nand_uart0.img D:\t113_work\t113_led_key.img
```

**烧录**（你操作）：
1. PhoenixSuit → 选固件
2. 板子断电 → 按住 **LOAD** → 插 DEBUG 线 → 叮咚后 3 秒松手

---

## 第 5 部分：验证

### LED 验证

**在哪**：板子终端（`adb shell` 或串口）
**敲什么**：

```sh
# ① 看设备有没有注册
ls /sys/class/leds/
# 期望看到：kelpbar:led1

# ② 点亮
echo 255 > /sys/class/leds/kelpbar:led1/brightness

# ③ 熄灭
echo 0 > /sys/class/leds/kelpbar:led1/brightness
```

**看到 LED1 亮了 = 成功。**

> **不亮怎么办？** 翻转极性试试：把 dts 里的
> `GPIO_ACTIVE_HIGH` 改成 `GPIO_ACTIVE_LOW`，重编重烧。
> **这是正常的调试步骤，不是失败。**

### 按键验证（★ 两步）

#### 第一步：确认设备注册了

```sh
cat /proc/bus/input/devices
```

**找什么**：`N: Name="gpio-keys"` 那一段，看它的 `H: Handlers=` 行。

**我看到的**：

```
N: Name="gpio-keys"
H: Handlers=kbd event4
B: KEY=80000
```

> ### ⚠️⚠️ 关键坑：设备名**不是** `kelpbar:btn1`
>
> 5.4 内核的 `gpio_keys` 驱动**不用 label 属性做设备名**，
> 设备名是**驱动名** `"gpio-keys"`。
>
> **所以 `grep kelpbar` 会零输出** —— 当时以为按键没注册，其实注册了。
> **要 `grep gpio` 才对。**
>
> `B: KEY=80000` 这个位图也证实了：第 115 位置位（115 = 0x73，
> 对应 KEY=80000 的 bit 位）= 我们 dts 里写的 `linux,code = <115>` 生效了。

#### 第二步：抓按键事件

```sh
# 开一个采样（板子上 busybox 没有 timeout，用手动中断）
cat /dev/input/event4
```

**然后用手按 BTN1** → 屏幕应该**刷出二进制乱码**（看不懂是正常的，那是原始事件包）。

**按 Ctrl+C 退出。**

#### 第三步（进阶）：把乱码翻译成人话

```sh
# 采样 45 秒到文件
cat /dev/input/event4 > /tmp/btn.raw
# （期间反复按 BTN1，然后 Ctrl+C）

# 看十六进制
hexdump -C /tmp/btn.raw | head -20
```

**怎么看**（192 字节 = 12 个事件，每个事件 16 字节）：

```
01 00 73 00 01 00 00 00
│  │  │  │  └──┴─ value = 1（按下）
│  │  └──┴─ code = 0x73 = 115（KEY_VOLUMEUP）
└──┴─ type = 0x0001 (EV_KEY 按键事件)
```

**按下和松开是一对**：

```
01 00 73 00 01 00 00 00    ← 按下（value=1）
01 00 73 00 00 00 00 00    ← 松开（value=0）
```

> **我用的是「AI 发起采样 + 用户同时按按键」的配合方式** —— 因为按键是物理动作，我在这头按不了。

### 终极验证工具：GPIO debugfs

```sh
mount -t debugfs none /sys/kernel/debug 2>/dev/null
cat /sys/kernel/debug/gpio | grep -E "kelpbar|gpio-10"
```

**我看到的**：

```
gpio-106 (kelpbar:btn1) in  hi IRQ ACTIVE LOW
gpio-107 (kelpbar:led1) out lo
```

**逐项读**：

| 字段 | 含义 |
|---|---|
| `in` / `out` | 输入/输出方向 |
| `hi` | 当前电平是高（按键没按下时的上拉状态） |
| `IRQ` | **中断已挂载** ✅ |
| `ACTIVE LOW` | 低电平有效（按下时拉低） |
| `gpio-106` / `gpio-107` | 全局引脚号（3×32+10=106，3×32+11=107）✅ |

> **debugfs 是终极真相** —— 它直接读硬件寄存器状态，
> **比任何日志都可靠**。怀疑"到底有没有工作"时，先看它。

---

## 第 6 部分：成功标志

| # | 检查项 | 怎么验证 | 期望 |
|---|---|---|---|
| 1 | LED 设备注册 | `ls /sys/class/leds/` | 见 `kelpbar:led1` |
| 2 | **LED 点亮** | `echo 255 > /sys/class/leds/kelpbar:led1/brightness` | **灯亮** |
| 3 | 按键设备注册 | `grep -A5 gpio /proc/bus/input/devices` | 见 `Name="gpio-keys"` + `event4` |
| 4 | **按键有事件** | `cat /dev/input/event4` 后按 BTN1 | **刷出事件流** |
| 5 | GPIO 状态正确 | `cat /sys/kernel/debug/gpio` | `IRQ ACTIVE LOW` |

---

## 第 7 部分：踩坑档案

| # | 症状 | 真因 | 解法 |
|---|---|---|---|
| 1 | LED 不亮 | 内核开关没开 | 开 6 个开关（含父开关） |
| 2 | **LED 亮但按键没反应** | 只开了 `GPIO_KEYS`，漏了 **`KEYBOARD_GPIO`** | 补开 |
| 3 | `grep kelpbar` 零输出 | **设备名是驱动名 `gpio-keys`，不是 label** | 搜 `gpio` |
| 4 | `/dev/input/event2` 吐乱码 | **不是按键**！是评估板残留的电阻触摸（sunxi-ts）空抖 | 认设备靠 **Name 匹配** |
| 5 | 改了 dts 不生效 | **`sed -i` 破坏软链接** | 改真身 |
| 6 | 点灯亮但极性和预期反 | 硬件极性和推测不同 | 翻转 `GPIO_ACTIVE_*` 重烧 |

> ### ⭐ 第 3、4 项是同一课
> **认设备要认名字，不要认"谁在动"。**
> 一个假设备恰好在吐数据（event2），会让你以为找对了。

---

## 第 8 部分：常考问题

**Q1：为什么 `LEDS_GPIO` 要配 `NEW_LEDS` 和 `LEDS_CLASS`？**
A：Linux 内核的配置项有**依赖链**。`NEW_LEDS` 是 LED 子系统框架（父），`LEDS_CLASS` 是设备类（中间层），`LEDS_GPIO` 才是具体驱动（子）。只开子不开父，配置无效。

**Q2：为什么 LED 和按键的驱动名这么像，却要开两个？**
A：`CONFIG_GPIO_KEYS` 是按键**子系统杂项**，`CONFIG_KEYBOARD_GPIO` 是 **gpio-keys 驱动本体**。名字像但作用不同 —— 只开前者，dts 节点就成了"没人认领的孤儿"。

**Q3：按键为什么不用写中断处理代码？**
A：`gpio-keys` 驱动**内置**了中断处理、去抖、事件上报。你只要在设备树里"登记"，驱动自动干活。这是 Linux 驱动的设计哲学：**配置代替编码**。

**Q4：怎么确认按键真的工作了？**
A：三层验证：① `/proc/bus/input/devices` 看设备注册（靠 **Name** 匹配）② `cat /dev/input/event4` 抓事件流 ③ `debugfs` 看 GPIO 寄存器状态（`IRQ ACTIVE LOW`）。**debugfs 是终极真相。**

**Q5：`linux,code = <115>` 是什么意思？**
A：按键上报的键码，115 = `KEY_VOLUMEUP`。**随便选个合法键码即可**，它只是标识"哪个键被按了"。

---

## 附录A：文件路径

### VM 里

| 用途 | 路径 |
|---|---|
| 内核配置 | `~/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand/linux-5.4/config-5.4` |
| 设备树真身 | `~/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand/linux-5.4/board.dts` |
| 编译产物配置 | `~/T113-Tina5.0-V1.2/out/t113/kernel/build/.config` |
| 镜像 | `~/T113-Tina5.0-V1.2/out/t113_linux_evb1_auto_nand_uart0.img` |

### 板子里

| 用途 | 路径 |
|---|---|
| LED 设备 | `/sys/class/leds/kelpbar:led1/` |
| LED 亮度 | `/sys/class/leds/kelpbar:led1/brightness` |
| 输入设备列表 | `/proc/bus/input/devices` |
| 按键事件流 | `/dev/input/event4` |
| GPIO 状态 | `/sys/kernel/debug/gpio` |

### Windows

| 用途 | 路径 |
|---|---|
| adb | `D:\t113_work\flash_tools\adb.exe` |
| 成品镜像 | `D:\t113_work\t113_led_key.img` |

---

## 附录B：复刻自检清单

- [ ] 我知道 LED 是 **PD11**，按键是 **PD10**
- [ ] 我知道 PD11 在 dts 里写成 `&pio 3 11`
- [ ] 我开了 **6 个**内核开关（不是 3 个）
- [ ] 我知道 `GPIO_KEYS` 和 `KEYBOARD_GPIO` 的区别
- [ ] 我知道 `board.dts` 是软链接，不能 `sed -i`
- [ ] 我用 `echo 255 > brightness` 点亮了 LED
- [ ] 我用 **Name 匹配**找到了按键设备（不是靠"谁在动"）
- [ ] 我看懂了 hexdump 的按键事件结构
- [ ] 我用 debugfs 确认了 GPIO 状态

**全部打勾 = 你独立复刻成功。**

---

*文档版本：v2.0 ｜ 2026-09-30 盖章*
