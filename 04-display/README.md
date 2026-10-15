# 考核④ 显示：八色彩条 + 复位自动恢复

## 状态：✅ 已完成（2026-10-09）

| 项目 | 结果 |
|---|---|
| 屏幕点亮 | ✅ 八色彩条 |
| 分辨率 | ✅ 720×1424 |
| 面板驱动 | ✅ FL7707N MIPI DSI，4 lane |
| **复位自动恢复** | ✅ 写入 `/etc/rc.local`，已落盘 `/overlay/upper/` |
| 成品镜像 | `t113_lcd_v6_bar1424.img`（22,699,008 字节） |

---

## ★ 完整复刻教程

**本文档只是速查。完整的保姆级复刻步骤看这里：**

### 👉 [`doc/显示-从黑屏到彩条全程教程.md`](doc/显示-从黑屏到彩条全程教程.md)

那份文档（1140 行）包含：
- 开工前准备清单 + 三窗口速查表
- 四个必备概念（BSP三层 / 设备树 / sysfs / overlayfs）
- **六层挖根全过程**（黑屏→找到真凶的完整推理链）
- 屏幕驱动注册四件套（可复制）
- 编译打包烧录全流程
- **彩条持久化 12 步**（每步含命令 + 逐行解释 + 验证关卡）
- 成功标志 8 项 / 踩坑档案 11 条 / 老师追问 6 问
- 文件路径全表 + 复刻自检清单

---

## 速查：关键结论

> **黑屏真凶 = U-Boot 的编译宏 `CONFIG_BOOT_GUI` 无条件开屏**，
> 它让内核走 `smooth display` 跳过屏幕初始化。
>
> **`lcd_used` 不是开关**（只用于分辨率合法性校验）—— 这是第一个陷阱。

### 六层挖根路径

```
① 日志无 lcd_open_flow 系列     → 内核没初始化屏幕
② 日志有 smooth display screen  → U-Boot 抢先开屏，内核礼让
③ 改 lcd_used=0 无效            → 它不是开关（陷阱）
④ 追代码找到 CONFIG_BOOT_GUI    → 真开关
⑤ 关宏重编，镜像小 32KB         → 物证：GUI 代码被裁掉
⑥ fb 1024×600 ≠ 面板 720×1424   → 改 fb0_width/height
```

### 彩条持久化的原理

```
问题: echo 1 > /sys/class/disp/disp/attr/colorbar 改的是【内核内存变量】→ 重启清零
解法: 写进 /etc/rc.local（开机最后一环 S95done 会调用它）
验证: ls /overlay/upper/etc/rc.local  ← 存在 = 已落盘，重启不丢
时序: disp 驱动 2.03s 就绪，rc.local 执行更晚 → 安全
```

---

## 速查：关键命令

```sh
# 看分辨率
adb shell "cat /sys/class/disp/disp/attr/xres; cat /sys/class/disp/disp/attr/yres"
# → 720 / 1424

# 手动开彩条
adb shell "echo 1 > /sys/class/disp/disp/attr/colorbar"

# 验证自启脚本已落盘（★ 最关键的一步）
adb shell "ls -la /overlay/upper/etc/rc.local"

# 验证是否真重启了
adb shell "cat /proc/uptime"    # 第一个数字 = 运行秒数

# 看显示状态总览
adb shell "cat /sys/class/disp/disp/attr/sys"
```

> **Windows 侧 adb**：`D:\t113_work\flash_tools\adb.exe`
> **Git Bash 里要加** `MSYS_NO_PATHCONV=1` 前缀（否则 Linux 路径被改写成 Windows 路径）

---

## 目录说明

| 目录/文件 | 内容 |
|---|---|
| `doc/显示-从黑屏到彩条全程教程.md` | ★ **完整复刻教程（1140 行）** |
| `patches/rc_local_new.sh` | 开机脚本（含彩条命令） |
| `patches/rc_local_on_board.txt` | 板子上实际运行的 rc.local 存档 |
| `patches/patch_*.py` | 全部改动用到的 Python 脚本 |
| `logs/` | 串口日志片段 |

### patches 里各脚本干什么

| 脚本 | 作用 |
|---|---|
| `patch_fl7707.py` | 移植 FL7707N 驱动五件套 |
| `patch_panels_h.py` | 补 `panels.h` 的 extern 声明 |
| `patch_uboot_lcd.py` | 改 U-Boot 的 `lcd_used`（试过，无效） |
| `patch_bootgui.py` | ★ **关掉 `CONFIG_BOOT_GUI`（真凶）** |
| `patch_fb720.py` | 改 fb 尺寸 |
| `patch_bar1424.py` | ★ **改成 720×1424 正确时序** |
| `rc_local_new.sh` | ★ **开机自动显示彩条** |

---

## 下一步

考核⑤ 喇叭 —— **有利条件**：`/etc/rc.local` 里已有出厂预设的音频配置：

```sh
amixer cset name="HPOUT Switch" 1
amixer -Dhw:audiocodec cset name='MIC3 Input Select' 1
amixer -Dhw:audiocodec cset name='MIC3 Switch' 1
amixer -Dhw:audiocodec cset name='ADC3 Gain' 19
```

**这四行同时是考核⑤（喇叭）和⑥（MIC）的开机配置，起点比显示这关平得多。**

---

*最后更新：2026-10-09 ｜ 对应镜像 t113_lcd_v6_bar1424.img*
