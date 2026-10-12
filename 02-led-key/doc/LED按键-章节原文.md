## 【考核②】LED 点灯

### 0. 目标一句话

让板子上的 LED1 亮起来、灭下去——由我们敲的命令控制。

### 1. 第一步：查原理图，确认 LED 接在哪个引脚、怎么点亮

**在哪看**：`D:\t113_work\kelpbar_docs\海带Linux智慧\SCH_Schematic_2026-09-24.pdf` 第 4 页

**看什么**：LED1 元件的连接。它一端接 VCC-IO（3.3V），另一端经 R124（10kΩ 限流电阻）接网络 **LED1**，LED1 网络连到主芯片。

**我看到的**：LED1 网络从灯连向 T113S3 芯片，具体接在 **PD11** 脚。

**为什么这步**：LED 接在 3.3V 和引脚之间 = 引脚输出**低电平**时电流流通（3.3V → LED → 电阻 → 引脚 → 地）→ 灯亮；引脚输出高电平（也是 3.3V）两边等电位没电流 → 灯灭。**这叫"低电平点亮"**。不查原理图就写代码=闭眼开车。

**要不要推挽输出？** 要。推挽（push-pull）= 引脚既能主动输出高也能主动输出低，点 LED 足够（LED 电流才几 mA）。开漏（open-drain）只能拉低，是给 I2C 总线用的。内核 GPIO 驱动默认就是推挽，不用额外配。

**引脚号怎么定**：LED1 接 **PD11**。两个证据：①原理图第 1 页主芯片框图坐标配对（PD11 脚旁接 LED1 网络）；②交叉验算：PD 组 sysfs 编号 = 3×32+11 = **107**，与课程文档"LED1=PD11, sysfs 107"吻合。

### 2. 第二步：确认内核要开哪些开关

**原理**：内核里 LED 走 LED 子系统：
```
echo 255 > /sys/class/leds/kelpbar:led1/brightness
  → LED 子系统(CONFIG_LEDS_CLASS 提供 /sys 目录)
  → GPIO 灯驱动(CONFIG_LEDS_GPIO, 专管"接 GPIO 上的灯")
  → 驱动查设备树 kelpbar:led1 节点 → 知道是 PD11 → 拉电平
```
sysfs 的 GPIO 接口还需要 `CONFIG_GPIO_SYSFS`。

**在哪改**：`~/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand/linux-5.4/config-5.4`

**怎么改**：
```bash
cd ~/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand/linux-5.4
cp config-5.4 config-5.4.bak-0930
printf '\nCONFIG_NEW_LEDS=y\nCONFIG_LEDS_CLASS=y\nCONFIG_GPIO_SYSFS=y\nCONFIG_LEDS_GPIO=y\n' >> config-5.4
```
（`printf '文本' >> 文件` = 追加到文件末尾；>> 是追加，> 是覆盖，别用错。）

**验证**：
```bash
grep -E 'NEW_LEDS|LEDS_CLASS|GPIO_SYSFS|LEDS_GPIO' config-5.4
```
四行全出来 = 改对。

**为什么连 NEW_LEDS、LEDS_CLASS 一起加**：内核 Kconfig 有依赖关系——LEDS_GPIO 依赖 LED 子系统框架，只写 LEDS_GPIO=y 不写它爹，编出来还是空。一次把依赖全家写上。

### 3. 第三步：设备树里"登记"这颗灯

**原理**：设备树（dts）= "这块板上有什么硬件、接哪个脚"的说明书，内核启动时读它认硬件。LED 子系统只有在设备树看到 gpio-leds 节点才会创建 /sys/class/leds/xxx。

**在哪改**：`~/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand/linux-5.4/board.dts` —— **这是软链接指向的真身，必须改这里**（改软链接=白改，见考核①软链接陷阱）。

**怎么改**（在 linux-5.4 目录里）：
```bash
cp board.dts board.dts.bak-0930-led
cat >> board.dts << 'EOF'

/ {
	leds {
		compatible = "gpio-leds";
		led1 {
			label = "kelpbar:led1";
			gpios = <&pio 3 11 GPIO_ACTIVE_LOW>;
			default-state = "off";
		};
	};
};
EOF
grep -n "kelpbar" board.dts
```
（`cat >> 文件 << 'EOF'` = 把两 EOF 之间的文字原样追加到文件尾；最后 EOF 必须单独一行顶格。）

**逐行解释**：
- `/ { }`：根节点。设备树允许多个根块，编译时自动合并——所以"追加到文件尾"合法
- `compatible = "gpio-leds"`：**钥匙行**。内核 gpio-leds 驱动就搜这个字符串，匹配上就接管本节点
- `label = "kelpbar:led1"`：给灯起名 → 变成 /sys/class/leds/ 下的目录名
- `gpios = <&pio 3 11 GPIO_ACTIVE_LOW>`：三段信息：
  - `&pio` = 所有引脚归 pio 控制器管（引用它）
  - `3 11` = 第 3 组第 11 脚。全志组号 A=0、B=1、C=2、**D=3**、E=4…（按字母序）→ 第 3 组=PD → PD11
  - `GPIO_ACTIVE_LOW` = **低电平=有效（亮）**——就是第一步从原理图判断的"低电平点亮"
- `default-state = "off"`：开机默认灭

**验证**：`grep -n "kelpbar" board.dts` 看到 led1 一行。
**再验一个**：`grep -c "gpio-leds" board.dts` 必须等于 1（**大于 1 = 贴重复了**，重复节点是后面按键的坑，LED 这里就会中招）。

### 4. 第四步：编译 + 打包

```bash
cd ~/T113-Tina5.0-V1.2 && ./build.sh && ./build.sh pack
```
改了内核配置要真重编（10-20 分钟），结尾必须看到 `build OK.` 和 `pack finish`。

**验证镜像是新的**：
```bash
ls -la out/t113_linux_evb1_auto_nand_uart0.img
```
时间戳必须是刚刚。（踩过的坑：一次烧完改动没生效，查时间戳发现镜像还是修改前打的——旧镜像骗人。）

### 5. 第五步：拉回 + 烧录 + 上板验证

**拉回**（Windows cmd 里）：
```
scp -P 2222 karry@127.0.0.1:/home/karry/T113-Tina5.0-V1.2/out/t113_linux_evb1_auto_nand_uart0.img D:\t113_work\
```
（scp=走 SSH 传文件；-P 2222=端口，P 大写；密码 `@Yao1881357` 不显示是正常）

**烧录**（PhoenixSuit）：一键刷机 → 选镜像 → 全盘擦除升级 → 断电 → 按住 LOAD → 插 DEBUG 线 → 叮咚 3 秒松 → 绿勾。

**进 shell**（二选一）：
- 串口：双击 `D:\t113_work\串口终端.bat`，出现 `Please press Enter to activate this console` 后按回车
- adb：Windows cmd → `cd /d D:\t113_work\flash_tools` → `adb devices` 确认设备在 → `adb shell`

**验证 LED**（板子 shell 里）：
```bash
ls /sys/class/leds/
```
输出有 `kelpbar:led1` = 节点被内核认领了。

```bash
echo 255 > /sys/class/leds/kelpbar:led1/brightness
```
→ **看板子**：LED1 亮。（255=最亮。因为配了 ACTIVE_LOW，255 输出的是低电平，而 LED 是低电平点亮——逻辑闭环。）

```bash
echo 0 > /sys/class/leds/kelpbar:led1/brightness
```
→ LED1 灭。

**如果不亮**：极性反了。土办法直接 `echo 0` 试（0 输出高电平，高有效灯就亮了）；确定极性后改 dts 的 ACTIVE_LOW/HIGH 重编。**用实测反推极性是正常流程不是失败。**

**如果 ls 里没有 kelpbar:led1**：三层排查——
```bash
# ①dtb 里有没有节点（VM 里跑）
dtc -I dtb -O dts out/t113/kernel/build/arch/arm/boot/dts/board.dtb | grep kelpbar
# ②内核开关编进去没（VM 里跑）
grep LEDS_GPIO out/t113/kernel/build/.config
# ③驱动注册没有（板子上跑）
dmesg | grep -i led
```

### 6. 结果（2026-09-30）

```
root@TinaLinux:/# ls /sys/class/leds/
kelpbar:led1
root@TinaLinux:/# echo 255 > /sys/class/leds/kelpbar:led1/brightness
→ 板上 LED1 亮（实测）
```
终极佐证（debugfs 能直接看引脚实时状态）：
```
cat /sys/kernel/debug/gpio
 gpio-107 (kelpbar:led1) out lo    ← PD11：输出模式、当前低电平（灭）
```

---

## 【考核③】按键

### 0. 目标一句话

按下板子 BTN1，电脑端能读到"按下/松开"事件。

### 1. 第一步：查原理图

**在哪看**：同一份原理图第 4 页按键部分。

**我看到的**：按键 SW5（TS-1088-AR02016 轻触开关）一端接地（GND），另一端接网络 **BTN1**；BTN1 网络经 R126（10kΩ）**上拉到 VCC-IO**，还挂了 100nF 电容 C124 到地（硬件消抖）。

**判断**：不按 → BTN1 被 10k 上拉成**高电平**；按下 → 直通地 = **低电平**。**这叫"按下低电平"**。软件配置：输入模式、低电平有效（外部已有上拉电阻，内部上拉开不开都行）。

**引脚号**：BTN1 接芯片 **PD10** 脚（原理图坐标配对：PD10(67脚) 旁接 BTN1 网络、PD11(68脚) 旁接 LED1 网络）。交叉验证：PD10 的 sysfs 编号 = 3×32+10 = 106。

### 2. 第二步：内核开关

**原理**：按键事件走 input 子系统：
```
按下 BTN1 → PD10 电平变低 → gpio-keys 驱动捕获(它注册了中断,电平变化立即触发)
  → 驱动翻译成"按键事件"(按下/松开) → 进 input 子系统 → 出现在 /dev/input/eventX → cat 它就能读到
```
需要的开关：
- `CONFIG_INPUT=y`、`CONFIG_INPUT_EVDEV=y`（input 子系统和 event 接口，方案里已有）
- `CONFIG_KEYBOARD_GPIO=y`（**gpio-keys 驱动本体**——认领 btn1 节点的就是它）
- `CONFIG_GPIO_KEYS=y`（input 杂项支持）

**⚠️ 大坑（真实踩过）**：`CONFIG_KEYBOARD_GPIO` 和 `CONFIG_GPIO_KEYS` 是**两个不同的 CONFIG**，名字像但作用不同——GPIO_KEYS 只是 input 子系统一小段支持代码，**KEYBOARD_GPIO 才是解析设备树 gpio-keys 节点的驱动**。只加 GPIO_KEYS 不加 KEYBOARD_GPIO = 驱动不存在 = 节点没人认领 = 设备永远不出现。我们就这么漏过，烧了一轮才发现。

**怎么改**：
```bash
printf '\nCONFIG_KEYBOARD_GPIO=y\nCONFIG_GPIO_KEYS=y\n' >> config-5.4
grep -E 'KEYBOARD_GPIO|GPIO_KEYS' config-5.4
```

### 3. 第三步：设备树加按键节点（和 LED 一起、同一次追加）

```bash
cat >> board.dts << 'EOF'

/ {
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
```
**逐行解释**：
- `compatible = "gpio-keys"`：钥匙——KEYBOARD_GPIO 驱动搜这个字符串
- `gpios = <&pio 3 10 GPIO_ACTIVE_LOW>`：PD10（组3第10脚），**低电平=按下**（和第一步判断一致：按下接地变低）
- `linux,code = <115>`：按下后上报什么"键值"。115=KEY_VOLUMEUP（音量+）。键值就是数字编号，内核有标准表（include/dt-bindings/input/linux-event-codes.h），考核只要求"能收到事件"，选哪个都行
- `wakeup-source`：能唤醒休眠（现在用不到，无害）
- **不用写中断**：gpio-keys 驱动看到 gpios 属性会自动配成边沿中断输入——引脚方向、上拉、中断全由驱动代劳，这是"驱动代劳"和"手写寄存器"的区别

**验证（两条都要做）**：
```bash
grep -n "kelpbar" linux-5.4/board.dts        # 要看到 btn1
grep -c "gpio-keys {" linux-5.4/board.dts    # 必须等于 1，大于 1 = 贴重复了！
```

### 4. 第四步：编译打包烧录（和 LED 同一次）

```bash
cd ~/T113-Tina5.0-V1.2 && ./build.sh && ./build.sh pack
```
**这次日志里要找一行**：`CC drivers/input/keyboard/gpio_keys.o` ——看到它=按键驱动真的在编（没看到=开关没生效）。

### 5. 第五步：上板验证（按键怎么"看"）

按键没有视觉反馈，输出的是**事件流**。验证分两步：

**5.1 确认设备注册**（板子 shell 里）：
```bash
cat /proc/bus/input/devices
```
找这样一段：
```
N: Name="gpio-keys"
H: Handlers=kbd event4 
B: KEY=80000 0 0 0
```
读法：
- `Name="gpio-keys"` = 节点被驱动认领了
- `Handlers=... event4` = 事件从 `/dev/input/event4` 读（**这个 event 号每次可能变，以实际输出为准**）
- `KEY=80000` = 键值位图，0x80000 的位 = 键值 115 → 正是配的 KEY_VOLUMEUP

**没找到 gpio-keys 的排查顺序**：
```bash
# ①驱动 probe 了吗、报什么错（板子上）
dmesg | grep -iE 'gpio-keys|gpio_keys'
# ②引脚被谁占用、什么模式什么电平（板子上，最直接）
cat /sys/kernel/debug/gpio | grep btn1
```
②的正确输出（我们的实锤）：
```
gpio-106 (kelpbar:btn1) in hi IRQ ACTIVE LOW
```
读法：PD10 输入模式、当前电平高（没按，上拉着）、**中断已挂**、低有效——**这行=硬件电路+驱动配置全对的铁证**。

**踩过的坑（排查时别被假设备骗）**：`/dev/input/event2` 会不停吐乱码——那不是按键，是评估板方案的电阻触摸屏（sunxi-ts）空抖（我们板触摸脚悬空产生假事件）。**认设备靠 /proc/bus/input/devices 的 Name 匹配，不靠"哪个吐码看哪个"**。

**5.2 读事件流**：
```bash
cat /dev/input/event4
```
**手指按 BTN1**：每按一次松一次，屏幕吐两坨"乱码"（按下一次+松开一次）。Ctrl+C 退出。

**乱码是什么**：按键事件是二进制结构体（时间戳8字节+类型2+键值2+值4=16字节/个），cat 到屏幕当然是乱码。**乱码出现=事件在流动=按键工作**。想看人话：

```bash
cat /dev/input/event4 > /tmp/btn.raw      # 板子上：抓事件流(抓的时候按按键)
```
然后 Windows cmd：
```
adb pull /tmp/btn.raw D:\t113_work\
```
再在 Windows 上用 python 解析（事件结构体 24 字节/个）：
```python
import struct
data = open(r'D:\t113_work\btn_events.raw','rb').read()
for i in range(0, len(data), 24):
    tv_sec, tv_usec, etype, code, value = struct.unpack('<qqhhi', data[i:i+24])
    if etype == 1:  # EV_KEY
        print('按下' if value==1 else '松开', '键值', code)
```

### 6. 结果（2026-09-30）

```
LED1：echo 255 亮 / echo 0 灭（实测）
BTN1：adb pull 事件文件 3072 字节 = 192 个事件
板上 hexdump /tmp/btn.raw：
  01 00 73 00 01 00 00 00   ← type=01(EV_KEY) code=73hex(=115) value=1(按下)
  00 00 00 00 00 00 00 00   ← value=0(松开)
  （按下/松开成对，192 个）
gpio debugfs 铁证：
  gpio-106 (kelpbar:btn1) in hi IRQ ACTIVE LOW
  gpio-107 (kelpbar:led1) out lo
```
**code=0x73=115=KEY_VOLUMEUP = 设备树里写的那个数字——从原理图到代码到事件全链路闭环。**

### 7. 本步踩坑汇总（三连坑，全部实证）

| 坑 | 现象 | 怎么定位 | 修复 |
|---|---|---|---|
| 软链接陷阱 | 改完验证对、上板没生效 | diff 真身和备份相同 + ls -la 看到箭头 | 改真身 linux-5.4/board.dts |
| CONFIG 名字陷阱 | 节点在、驱动编了、设备不出现 | 查 .config 发现 `CONFIG_KEYBOARD_GPIO is not set` | 补 KEYBOARD_GPIO=y |
| 重复节点 | 驱动编了、设备还是不出现 | tail 文件发现两份同名块 | head 截断去重 |

**通用排查心法**：
1. 每环节改完立刻验证：源文件→grep；编译→看关键 .o 行（`CC gpio_keys.o`）；镜像→时间戳；上板→/proc 和 dmesg
2. 不猜：dtb 反编译看节点、.config 看开关、/proc 看设备、debugfs 看引脚——**每层都有工具看真相**
3. "LED 好了按键没好"这种**不对称现象**是重要线索：共享部分（config/dts 路径）没问题，差异部分（各自驱动/节点）才是凶手