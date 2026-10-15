# 考核① debug 串口：让板子能打印日志 —— 复刻手册

> **目标**：串口能打印出完整启动日志，能进 shell 交互。
> **已盖章**：2026-09-30
> **前置**：无（这是所有外设调试的地基）

---

## 第 0 部分：开工前准备

| # | 需要什么 | 说明 |
|---|---|---|
| 1 | **USB 转串口线** | 板子 DEBUG TypeC 口接电脑 |
| 2 | **串口终端软件** | `D:\t113_work\串口终端.bat`（交互版）或 `串口日志.bat`（只读版） |
| 3 | **VM 能连上，SDK 在** | VM 里 `ls ~/T113-Tina5.0-V1.2` |
| 4 | **知道三个终端的区别** | 见下方速查表 |

### ★ 三窗口速查表

| 终端 | 提示符 | 干什么 |
|---|---|---|
| **VM 终端** | `karry@karry-VirtualBox:~$` | 改代码、编译、打包 |
| **Windows 终端** | `C:\Users\XYT>` | adb、scp、开串口终端 |
| **板子终端** | `root@TinaLinux:/#` | 看板子状态（通过串口或 adb 进去） |

> **血泪教训**：把板子命令敲进 VM 终端，输出全是虚拟机的设备 —— 会让你以为板子坏了。**敲命令前先看提示符。**

> ### ⚠️ COM 口只能被一个程序占用
> `串口日志.bat` 和 `串口终端.bat` **不能同时开**。
> 第二个会报"拒绝访问"，看起来像"串口坏了"，其实就是抢占冲突。

---

## 第 1 部分：硬件事实

| 项目 | 值 |
|---|---|
| 调试串口 | **UART3** |
| TX / RX | **PB6 / PB7** |
| 接口位置 | U24 三针座 |
| 参数 | **115200-8N1** |
| DEBUG TypeC | USB0 |

### ★ 为什么"串口"这关最关键

**串口是系统起不来时，唯一能看到真相的通道。**

板子黑屏、不启动、卡死 —— 你没有任何界面可用，只能靠串口打印的日志判断卡在哪。

所以这一关是**所有其他外设诊断的地基**，也解释了为什么它花的时间最长。

---

## 第 2 部分：三级验证（逐级打通）

### 第1级：物理级 —— 线接对了吗

**症状**：串口终端完全没输出。

**排查**：
1. USB 转串口线是否插好（看设备管理器有没有新的 COM 口）
2. **TX/RX 是否交叉**（板子的 TX 要接转换线的 RX，反之亦然）
3. 板子是否上电

### 第2级：电气级 —— 波特率对吗

**症状**：有输出但是乱码。

**排查**：波特率必须是 **115200**。乱码 = 波特率不匹配。

### 第3级：系统级 —— 系统跑稳了吗

**症状**：能打印前面几行，但卡在中间。

**排查**：看日志卡在哪一层。

**成功标志**：

```
[00:00:00] [29]HELLO! BOOT0 is starting!
```

之后依次出现 boot0 → U-Boot → kernel → rootfs 全部日志。

---

## 第 3 部分：★ 核心坑 —— 调试口引脚要移植

> **这是本关最重要的一课，也是"为什么需要移植"的经典案例。**

### 问题

初始烧录官方镜像后，**串口一个字符都没有**。

### 真因

官方方案是给**评估板**做的，评估板的调试口配在 **PG8/PG9**，
但**我们这块板**的调试口线接在 **PB6/PB7**。

**配置和硬件对不上 → 日志发到了一个没人听的脚上。**

### 这就是"移植"的含义

> 官方 BSP 给的是**评估板**的配置。
> 你的板子硬件不一样，就必须**改软件配置去匹配硬件**。
> 这就是 BSP 工程师的日常，也是老师考的核心能力。

### 要改三处（★ 缺一不可）

三处配置分别在 SDK 的不同地方，管的**阶段不同**：

| 文件 | 管哪个阶段 | 要改什么 |
|---|---|---|
| `openwrt/env.cfg` | 内核启动参数 | `earlycon` 地址 |
| `sys_config.fex` | **引导期**串口（U-Boot） | 引脚 + 功能号 |
| `board.dts` | **内核期**串口引脚 | 引脚名 |

**完整路径前缀**：

```
~/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand/
```

#### 改动①：`openwrt/env.cfg`

**找到**：
```sh
cd ~/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand
grep -n "earlycon\|console=" openwrt/env.cfg
```

**原始值**（评估板地址）：
```
早期: earlycon=...0x05000000
```

**改成**（我们的地址）：
```
earlycon=...0x02500C00
```

**操作**：
```sh
cp openwrt/env.cfg openwrt/env.cfg.bak-serial
sed -i 's/0x05000000/0x02500C00/' openwrt/env.cfg
grep -n "0x02500C00" openwrt/env.cfg      # 验证
```

> **为什么地址不一样？** 因为这是**串口寄存器的物理地址**，评估板和本板的 UART3 地址映射不同。
> 地址错了，earlycon（早期控制台）就打印不出来。

#### 改动②：`sys_config.fex`

**找到**：
```sh
grep -n -A3 "uart_para" sys_config.fex | head -20
```

**原始值**：
```
uart_debug_port = 3           ← 端口号对（UART3）
uart_debug_tx   = port:PG08<5>
uart_debug_rx   = port:PG09<5>
```

**问题**：端口号对，但**引脚是评估板的 PG8/PG9**。

**改成**：
```
uart_debug_tx   = port:PB06<7>
uart_debug_rx   = port:PB07<7>
```

**操作**：
```sh
sed -i 's/port:PG08<5>/port:PB06<7>/' sys_config.fex
sed -i 's/port:PG09<5>/port:PB07<7>/' sys_config.fex
grep -n "PB06\|PB07" sys_config.fex      # 验证
```

> ### ★★ `<7>` 这个功能号是怎么来的？（绝佳教学案例）
>
> 尖括号里的数字是**引脚复用功能号**。PG8 原来是 `<5>`，换到 PB6 时**不能沿用 5**。
>
> **怎么知道该填几？查内核 C 表（最高权威）**：
> ```sh
> grep -n -A8 'PINCTRL_PIN(B, 6)' \
>   ~/T113-Tina5.0-V1.2/kernel/linux-5.4/drivers/pinctrl/sunxi/pinctrl-sun8iw20.c
> ```
> ⚠️ **搜法注意**：C 表里引脚名是宏写法 `SUNXI_PINCTRL_PIN(B, 6)`（组名和脚号分开），
> 直接搜 `"PB6"` 是搜不到的。
> 看到 **PB6 的 `SUNXI_FUNCTION(0x7, "uart3")  /* TX */`** → 所以填 `<7>`。
>
> **交叉验证**：查 `PINCTRL_PIN(G, 8)` 看到 `SUNXI_FUNCTION(0x5, "uart3")  /* TX */`，
> 跟我们原来看到的 `<5>` 吻合 → **闭环，证明方法正确**。
>
> **规律**：**数据手册的 FunctionN 列 = 内核功能号 0xN**（PB6 手册 Function7=UART3-TX，
> 内核 `0x7="uart3"`，一一对应）——但**以内核 C 表为准**，设备树填的就是内核功能号。

#### 改动③：`board.dts`

**注意**：改**真身**！这个目录下的 `board.dts` 可能是软链接。

```sh
ls -la board.dts        # 看第一个字符是不是 l
```

**找到**：
```sh
grep -n 'pins = "PG8"' linux-5.4/board.dts
```

**改成**：
```sh
cp linux-5.4/board.dts linux-5.4/board.dts.bak-serial
sed -i 's/pins = "PG8", "PG9"/pins = "PB6", "PB7"/g' linux-5.4/board.dts
grep -n 'PB6\|PB7' linux-5.4/board.dts
```

> ### ⚠️ 结尾的 `g` 不能丢！
> `sed` 默认只替换**每行第一次**匹配。
> `uart3_pins_a` 和 `uart3_pins_b` 是**两处**，不加 `g` 只改一处 = 经典坑。
>
> 实际上 `pins = "PG8", "PG9"` 是同一行的两个值，`g` 在这里主要保证不漏。

**验证**：
```sh
sed -n '410,430p' linux-5.4/board.dts     # 眼见为实
```

---

## 第 4 部分：★ 编译时的陷阱（软链接）

> **这是整个项目最大的坑，值得单独讲。**

### 现象

你改了 `board.dts`，验证时确实看到改对了，但：
- 重编译、重烧录后，**改动就是不生效**
- 反复检查，源文件明明是对的

### 真因

**GNU 的 `sed -i` 修改软链接时，会销毁链接、在原地生成一个普通文件。**

```
改之前：  board.dts  --(软链接)-->  linux-5.4/board.dts  （真身）
sed -i 后：board.dts  （普通文件，你的改动在这里）
           linux-5.4/board.dts  （真身，一字未改！）
```

接着 `./build.sh` 发现布局被破坏，会**删掉那个普通文件、重建软链接**，指回原始版本。

**结果**：
- 你 `cat` 验证读的是**新文件**（改动在，看着成功）
- 编译读的是**真身**（永远原版）

> ### ⭐ 金句
> **验证和编译读的是两个文件 —— 平行线永不相交。**

### 正确做法

1. **改真身**（`linux-5.4/board.dts`）—— 推荐
2. **或用 Python 脚本**（`open()` 会穿透软链接）
3. **绝不用 `sed -i` 改软链接**

**每次改完必做**：
```sh
ls -la linux-5.4/board.dts     # mtime 应该是刚刚
```

---

## 第 5 部分：编译 → 打包 → 烧录

**VM 终端**：

```sh
cd ~/T113-Tina5.0-V1.2
./build.sh
source build/envsetup.sh
pack
```

**看到**：`build OK` → `pack finish`

**镜像**：
```sh
ls -la out/t113_linux_evb1_auto_nand_uart0.img
```

**拉回 Windows**（cmd）：
```cmd
scp -P 2222 karry@127.0.0.1:/home/karry/T113-Tina5.0-V1.2/out/t113_linux_evb1_auto_nand_uart0.img D:\t113_work\t113_serial.img
```

**烧录**（你操作）：
1. PhoenixSuit → 选固件
2. 板子断电 → 按住 **LOAD** → 插 DEBUG 线 → 叮咚后 3 秒松手

---

## 第 6 部分：★ 内核挂死排查（initcall 照妖镜）

### 现象

内核启动到某一处**精确卡死**，然后 16 秒后被看门狗复位，循环。

**关键特征**：**每次卡在同一行**（确定性，不是随机）。

> **怎么区分"卡死"和"我按了复位"？**
> 卡死 = **每次日志都停在完全相同的位置**；
> 手按复位 = 随机位置。
> **这是"用证据判定，不靠猜"。**

### 排查工具：`initcall_debug` 照妖镜

**原理**：内核启动时会逐个执行驱动的初始化函数（叫 initcall）。
打开调试开关后，**每个函数执行前后都会打印一行**：

```
calling  xxx_init+0x0/0x100        ← 开始执行
initcall xxx_init+0x0/0x100 returned 0 after 1234 usecs    ← 执行完成
```

**凶手 = 最后一个只有 `calling` 没有 `returned` 的驱动。**

**怎么打开**（改 `env.cfg`）：
```sh
cd ~/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand
sed -i 's/initcall_debug=0/initcall_debug=1/' openwrt/env.cfg
grep -n "initcall_debug" openwrt/env.cfg
```

> **改 env 只需 `pack`，不用重编内核**（内核没动）。

### 本次抓到的凶手

日志最后一行：

```
calling deferred_probe_initcall
```

没有下文 → **卡在 deferred_probe**。

**deferred_probe 是什么？** 内核的"**补考机制**"：
驱动初始化时如果依赖的东西还没准备好，会返回 `-517`（EPROBE_DEFER），
内核把它记下来，等会儿再试一次。

**搜 `-517`**：
```sh
grep -n "\-517" serial.log
```

**找到**：
```
probe of 2502c00.twi returned -517
```

`2502c00.twi` = **TWI3（一路 I2C 控制器）**。

**真因**：twi3 是**空总线**（上面挂的设备都 disabled 了），但控制器本身 `status="okay"`。
内核补考它时，I2C 传输**死等不超时** → 卡死。

**修改**：把 twi3 设成 `disabled`（改真身！）：

```sh
cd ~/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand
cp linux-5.4/board.dts linux-5.4/board.dts.bak-twi3

# 先找行号
grep -n "twi3" linux-5.4/board.dts
sed -n '905,915p' linux-5.4/board.dts      # 确认行号在 &twi3 块内

# 精准改（带行号前缀，只改那一处）
sed -i '912s/status = "okay"/status = "disabled"/' linux-5.4/board.dts

# 验证
sed -n '905,915p' linux-5.4/board.dts
```

> ### ⚠️ 防误伤
> `board.dts` 里有很多 `status = "okay"`。
> **`spi0` 上挂着 SPI NAND（启动必需），绝对不能关！**
> 所以必须**带行号精准改**，不能全局替换。

**改完重编重烧，日志应看到**：

```
sunxi_twi_adap_init returned 0 after ... usecs     ← twi3 不再被 probe
deferred_probe_initcall returned 0 after 484212 usecs   ← 补考顺利通过（484ms）
VFS: Mounted root (squashfs)
Run /init as init process
...
Please press Enter to activate this console.
```

### ★ 最后一个坑：Enter 没反应

看到 `Please press Enter to activate this console.` 后按 Enter 没反应？

**两个原因**：

1. **必须等这句话出现之后再按**。这之前的按键都被丢弃。
2. **串口终端脚本发的是 `\r`（回车），但 busybox 的 `askfirst` 等的是 `\n`（换行）**。
   → 修脚本：`ser.write((line + '\r\n').encode())`

**或者直接走 adb**（推荐，绕开这个问题）：
```sh
D:\t113_work\flash_tools\adb.exe shell
```

---

## 第 7 部分：成功标志

| # | 检查项 | 期望 |
|---|---|---|
| 1 | 串口有输出 | `HELLO! BOOT0 is starting!` |
| 2 | U-Boot 日志 | `U-Boot 2018.07-...` |
| 3 | 内核版本行 | `Linux version 5.4.61 ...` |
| 4 | 控制台就绪 | `Please press Enter to activate this console.` |
| 5 | **能进 shell** | 按 Enter 或 `adb shell` → `root@TinaLinux:/#` |
| 6 | 系统稳定 | **不复位循环** |

---

## 第 8 部分：踩坑档案

| # | 症状 | 真因 | 解法 |
|---|---|---|---|
| 1 | 串口全无输出 | 调试脚配在评估板 PG8/PG9，本板在 PB6/PB7 | 改三处配置 |
| 2 | 有输出但乱码 | 波特率不对 | 确认 115200 |
| 3 | 改了配置不生效 | **`sed -i` 破坏软链接** | 改真身 / 用 Python |
| 4 | 精确卡死循环 | 空总线 twi3 让 deferred_probe 死等 | twi3 设 disabled |
| 5 | 串口 COM 口突然消失 | USB 插拔后重新枚举（COM4→COM7） | 查设备管理器重连 |
| 6 | Enter 没反应 | `\r` vs `\n`；或按太早 | 修脚本 / 用 adb |
| 7 | 两个串口程序打架 | COM 口只能被一个程序占用 | 关掉另一个 |

---

## 附录A：文件路径

### VM 里

| 用途 | 路径 |
|---|---|
| SDK 根 | `~/T113-Tina5.0-V1.2` |
| 内核启动参数 | `<CFG>/openwrt/env.cfg` |
| 引导期串口 | `<CFG>/sys_config.fex` |
| 内核期引脚 | `<CFG>/linux-5.4/board.dts`（真身） |
| 引脚功能 C 表 | `~/T113-Tina5.0-V1.2/kernel/linux-5.4/drivers/pinctrl/sunxi/pinctrl-sun8iw20.c` |
| 镜像 | `~/T113-Tina5.0-V1.2/out/t113_linux_evb1_auto_nand_uart0.img` |

> `<CFG>` = `~/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand`

### Windows

| 用途 | 路径 |
|---|---|
| adb | `D:\t113_work\flash_tools\adb.exe` |
| 串口终端（交互） | `D:\t113_work\串口终端.bat` |
| 串口日志（只读） | `D:\t113_work\串口日志.bat` |
| 串口脚本 | `D:\t113_work\serial_term.py` |

---

## 附录B：复刻自检清单

- [ ] 我知道调试串口是 **UART3 / PB6,PB7 / 115200-8N1**
- [ ] 我能解释"为什么需要移植"（官方配置是给评估板的）
- [ ] 我改了**三处**配置（env.cfg / sys_config.fex / board.dts）
- [ ] 我知道功能号 `<7>` 是从**内核 C 表**查出来的
- [ ] 我知道 `board.dts` 是软链接，**不能用 `sed -i` 改**
- [ ] 我会用 `initcall_debug` 找卡死的驱动
- [ ] 我知道 `-517` = EPROBE_DEFER（补考）
- [ ] 我成功进了 shell

**全部打勾 = 你独立复刻成功。**

---

*文档版本：v2.0 ｜ 2026-09-30 盖章*
