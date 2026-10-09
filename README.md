# T113 KelpBar 全通计划 —— 节点工程总览

T113-s3 KelpBar 开发板嵌入式学习项目。**每个考核节点一个独立 git 工程**，互不干扰。

## 节点索引

| # | 节点 | 状态 | 工程目录 | 核心技术 |
|---|---|---|---|---|
| ① | debug 串口 | ✅ | [`01-serial`](../01-serial) | UART3 / PB6,PB7 / 115200-8N1 |
| ② | LED + 按键 | ✅ | [`02-led-key`](../02-led-key) | GPIO 子系统 / PD11,PD10 / evdev |
| ③ | 触摸 | ✅ | [`03-touch`](../03-touch) | GT9xx / TWI1 / PE0,PE1 / 0x5D |
| ④ | 显示 | ✅ | [`04-display`](../04-display) | FL7707N MIPI DSI / 720×1424 / rc.local 持久化 |
| ⑤ | 喇叭 | ⬜ | `05-speaker` | tinyplay / HPOUT |
| ⑥ | MIC | ⬜ | `06-mic` | tinycap / MIC3 |
| ⑦ | WiFi | ⬜ | `07-wifi` | RTL8723DS SDIO |
| ⑧ | BT | ⬜ | `08-bt` | MX-02 模组 |
| ⑨ | LVGL8/9 | ⬜ | `09-lvgl` | app_sdk_v2 |

## 每个工程的统一结构

```
0X-<节点名>/
├── README.md       # 结论速查：硬件事实 / 成功标志 / 踩坑档案 / 关键命令
├── doc/            # 保姆级全程教程（四段式）
├── patches/        # 全部改动脚本（Python，不用 sed -i）
└── logs/           # 串口日志精选片段（大文件 gitignore）
```

## 贯穿全项目的核心方法

### 1. 三层定位法 —— 出问题先问「改哪一层」
```
boot0(闭源) → U-Boot(可改/重编) → Kernel+设备树(可改/重编) → rootfs(板上直接改)
```
> 第4层 rootfs 最省事：**不用重编、不用烧录**，板子上直接改文件。

### 2. 排查口诀
| 金句 | 含义 | 出处 |
|---|---|---|
| **枚举 ≠ 应答** | dts 里声明了设备 ≠ 芯片真的应答 | 触摸 |
| **控制器对 ≠ 线对** | 总线号对了 ≠ 引脚对了 | 触摸 |
| **能力 ≠ 接线** | 芯片引脚"支持"某功能 ≠ 板上就接在那 | 触摸 |
| **谁开屏就改谁** | 黑屏要找到真正开屏的那段代码 | 显示 |
| **名字骗人，去看谁用它** | `lcd_used` 听起来像开关，实际不是 | 显示 |
| **认设备认名字** | 别信"谁在吐数据"，信 `/proc/bus/input/devices` | LED/按键 |

### 3. 四条铁律
1. **风险优先** —— 改文件前先备份
2. **信源** —— 参数去规格书/原厂代码抄，不猜
3. **三审** —— ①事实来源 ②逻辑 ③未验证假设
4. **90% 把握才动手**

### 4. 工具坑位
- **改 dts 禁用 `sed -i`** —— 会破坏符号链接，用 Python 脚本
- **`pack` 前先 `source build/envsetup.sh`** —— 它是 shell 函数不是程序
- **Git Bash 用 adb 加 `MSYS_NO_PATHCONV=1`** —— 否则 Linux 路径被改写成 Windows 路径

## 硬件事实总表

| 外设 | 引脚/参数 | 来源 |
|---|---|---|
| 调试串口 | UART3, TX=PB6, RX=PB7, 115200-8N1 | 数据手册 p41 复用表 |
| LED1 | PD11 | 原理图 |
| BTN1 | PD10 | 原理图 |
| 触摸 | GT9xx, TWI1, SCL=PE0, SDA=PE1, INT=PE5, RST=PE4, addr=0x5D | 原理图 p7 + 内核 C 表 + 上板 |
| 屏幕 | FL7707N, MIPI DSI 4-lane, 720×1424, 背光 PWM ch7 | 屏厂规格 |
| DEBUG TypeC | USB0 | 原理图 |

## 镜像版本记录

| 镜像 | 说明 |
|---|---|
| `t113_linux_evb1_auto_nand_uart0.img` | 串口基线 |
| `t113_touch_twi1_PE01.img` | 触摸点亮（21,550,080 B） |
| `t113_lcd_v5_nogui.img` | 关掉 U-Boot CONFIG_BOOT_GUI（比上版小 32KB，物证） |
| `t113_lcd_v6_bar1424.img` | **显示彩条达成**（22,699,008 B） |

> 镜像文件较大，未入 git。分发用 GitHub Release 或网盘。

## 关于 GitHub 推送

各仓库已 `git init` 并完成首次 commit，但**尚未配置远程仓库**。

推送步骤（需要你的 GitHub 账号）：

```sh
cd D:\t113_repos\04-display          # 进入某个节点仓库
git remote add origin https://github.com/<你的用户名>/t113-display.git
git branch -M main
git push -u origin main
```

> **建议**：4 个节点各建一个 repo（`t113-serial` / `t113-led-key` / `t113-touch` / `t113-display`），
> 符合你说的"串口是一个代码工程，触摸也是一个，分开切独立的"。

---
*最后更新：2026-10-09*
