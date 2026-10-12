# 考核⑤ 喇叭：播放音频 ✅ 已完成

## 两个固件版本

| 镜像 | 大小 | 能放什么 | 说明 |
|---|---|---|---|
| `t113_v7_speaker.img` | 21,519,360 B | 只有 **WAV** | 基础版（验证喇叭用） |
| **`t113_v8_music.img`** | **21,650,432 B** | **WAV + MP3** | ★ 推荐（含 madplay） |

> **v8 比 v7 大 128KB** = madplay + libid3tag 的体积（真的编进去了的物证）。

**播放命令**：

```sh
adb shell "aplay  /root/audio/test_440.wav"          # WAV
adb shell "madplay /root/audio/music_twinkle.mp3"    # MP3
```

**能放什么音乐、怎么加 MP3 支持** → 见 [`doc/能播放什么音乐-实测.md`](doc/能播放什么音乐-实测.md)

---

## 状态

| 项目 | 状态 |
|---|---|
| 声卡驱动 | ✅ 已就绪（`audiocodec` 已注册） |
| 播放通路 | ✅ 已验证（DAPM 全 On） |
| HPOUT 使能/音量 | ✅ 已配置 |
| **功放使能 PA_SHDN** | ✅ 已定位（PB2 = gpio-34）；★极性坑已修正（低=工作） |
| 开机自动配置 | ✅ 已写入 `/etc/rc.local`，重启验证通过 |
| **MP3 播放** | ✅ 已开启（v8 固件），实测 `308 frames decoded` |
| 测试音频 | ✅ 已生成并放入板子 `/root/audio/` |
| **听到声音** | ✅ **2026-10-10 用户确认有声音**（考核⑤盖章） |
| 音乐循环播放 | ✅ 4首曲子循环（音乐-循环播放.bat） |

---

## ★ 完整文档

| 文档 | 内容 |
|---|---|
| [`doc/喇叭-播放音频全程教程.md`](doc/喇叭-播放音频全程教程.md) | ★ 完整复刻教程（诊断链 / 原理图解读 / 时序陷阱 / 开机脚本 / 老师追问） |
| [`doc/能播放什么音乐-实测.md`](doc/能播放什么音乐-实测.md) | ★ 音乐播放实测（格式支持 / MP3 开启方法 / 实测记录） |

---

## 核心结论（一句话）

> **喇叭不出声的最后一个坑是极性：LM4871 的 SHUTDOWN 脚 `PA_SHDN`（接 PB2）
> 是「高电平关断 / 低电平工作」。**
> 板上的 100kΩ 下拉让它默认就是工作状态 —— **千万别拉高，拉高等于把功放关掉。**
> （TI 数据手册实锤：VDD applied to SHUTDOWN pin → shutdown mode activated）

---

## 硬件事实

| 项目 | 值 | 来源 |
|---|---|---|
| 音频芯片 | `audiocodec`（T113 内置） | `/proc/asound/cards` |
| 功放 | **LM4871**（3W 音频功放） | 原理图第 5 页 |
| 功放使能脚 | **PA_SHDN** | 原理图第 5 页 |
| 使能脚引脚 | **PB2**（低电平=工作，高电平=关断） | 原理图第 1 页（引脚 86）+ TI LM4871 手册 |
| 全局 GPIO 号 | **34**（1×32+2） | 计算 + 已知项交叉验证 |
| 喇叭座 | **CN2**（HC-1.25-2PWT） | 原理图第 5 页 |
| 信号来源 | HPOUTR（经 R136 20kΩ） | 原理图第 5 页 |
| 默认状态 | **工作**（R138 100kΩ 下拉 = 低电平 = 工作） | 原理图第 5 页 + 数据手册 |

---

## 速查：三条核心命令

```sh
# ① 功放使能（★ 低电平=工作！拉高反而关断）
adb shell "echo 34 > /sys/class/gpio/export; echo out > /sys/class/gpio/gpio34/direction; echo 0 > /sys/class/gpio/gpio34/value"

# ② 设置音量
adb shell "amixer cset name='HPOUT Switch' 1; amixer cset name='HPOUT Gain' 7; amixer cset name='DACL Volume' 200; amixer cset name='DACR Volume' 200"

# ③ 播放
adb shell "aplay /root/audio/test_440.wav"          # WAV
adb shell "madplay /root/audio/music_twinkle.mp3"   # MP3
```

> Windows 侧 adb：`D:\t113_work\flash_tools\adb.exe`
> Git Bash 里要加 `MSYS_NO_PATHCONV=1` 前缀

---

## 目录说明

| 文件 | 内容 |
|---|---|
| `doc/喇叭-播放音频全程教程.md` | ★ **完整复刻教程** |
| `doc/能播放什么音乐-实测.md` | ★ **音乐格式与实测** |
| `patches/rc_local_new.sh` | 开机自动配置脚本（音频 + 显示） |
| `patches/deploy_audio.sh` | **一键部署脚本**（推音频 + 检查环境，已实测） |
| `patches/gen_test_audio.py` | 生成测试音频的 Python 脚本 |
| `patches/test_440.wav` | 440Hz 标准音 A 测试文件 |
| `patches/test_scale.wav` | 音阶测试文件 |
| `patches/music_twinkle.wav` / `.mp3` | 小星星（WAV 与 MP3 对比用） |
| `patches/notify.mp3` | 短提示音 |
| `logs/镜像信息.md` | 镜像版本记录 |

---

## ★ 重要：配置已编入固件

**成品镜像**：`D:\t113_work\t113_v8_music.img`（21,650,432 字节）

配置写进了 **SDK 源文件**（不是板上临时改），所以：
- **烧录后开机就自带全部配置**，不需要手动敲任何命令
- 重烧也不会丢（之前改板子 `/etc/rc.local` 会因 overlay 清空而丢失）

详见 [`logs/镜像信息.md`](logs/镜像信息.md)。

---

## 双击即用（推荐，不用敲任何命令）

| 文件 | 干什么 |
|---|---|
| `D:	113_work\喇叭-播放测试.bat` | 一键测试：连板→部署文件→开功放→放WAV→放MP3 |
| `D:	113_work\喇叭-没声音排查.bat` | 没声音时双击：自动检查5项+自动修复+再播一次 |

> 两个脚本已实测跑通（2026-10-10 早上）。制作 bat 的坑：**内容必须纯 ASCII + CRLF 换行**，
> 否则 cmd.exe 解析碎裂（中文乱码命令、变量赋值失败）。

---

## 你明天要做的（3 步）

1. **插喇叭** → 板子的 **CN2** 座（2P 1.25mm）
2. （如果还没烧 v8）烧录 `t113_v8_music.img`
3. **双击** `D:	113_work\喇叭-播放测试.bat` → 听

**听到声音 = 考核⑤完成。** 零命令、零粘贴。

> 开机后**约 30 秒**配置才自动就绪（音频子系统初始化慢），等一下再播。
> 如果音频文件丢了（重新烧录后），跑 `bash patches/deploy_audio.sh` 重新部署。

---

## 如果没声音，按这个顺序排查

| 顺序 | 检查 | 命令 | 期望 |
|---|---|---|---|
| 1 | 功放使能 | `cat /sys/class/gpio/gpio34/value` | **`0`**（1 = 关断） |
| 2 | HPOUT 开关 | `amixer cget name='HPOUT Switch'` | `values=on` |
| 3 | 音量 | `amixer cget name='HPOUT Gain'` | `values=7` |
| 4 | 播放通路 | 播放中看 DAPM | `DACL/DACR/HPOUT` = `On` |
| 5 | 音频文件 | `ls /root/audio/` | 文件存在 |
| 6 | **物理连接** | 看喇叭是否插在 CN2 | 插紧 |

> **第 1 项注意**：值应该是 **0**（低电平=工作）。如果看到 1，就是被关断了。

---

## 下一步

考核⑥ MIC（录音回放）—— 好处：**共用同一张声卡**，
`rc.local` 里已经配好 `MIC3 Input Select/Switch/ADC3 Gain` 了。

---

*最后更新：2026-10-09 ｜ 含 MP3 支持，待听声*
