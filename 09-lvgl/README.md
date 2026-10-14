# 考核⑨ LVGL：无屏先行移植 —— 软件全就绪，等屏幕总成

> **目标**：LVGL 在板上跑起来（编译→部署→渲染→触摸接入全链路验证），换屏后插上就能看到画面。
> **状态**：✅ **软件侧 100% 完成**（2026-10-14：widgets demo 渲染实锤 + 触摸通路接入）；⏸ **仅差屏幕总成硬件**（FL7707 720×1424 MIPI 4lane）。
> **本关特殊性**：物理屏暂时看不到，但**显存里的画面能"云看"**——把 `/dev/fb0` 的内容拉回电脑转成图片（见第 5 部分）。本手册全部验证都用这个方法完成，**这些验证不依赖屏幕**。

---

## 0. 一图定案：LVGL 已经在跑了

下面这张图**不是模拟器截图，是板上 `/dev/fb0` 显存的真实内容**（adb 拉回转 PNG）——LVGL v8 官方 widgets demo 正在你的板子里渲染：

![板上 fb0 显存里的 LVGL widgets demo](doc/images/lvgl_fb_dump.png)

进程握着的设备（`ls -l /proc/<pid>/fd`）：

```
3 -> /dev/fb0              ← 显示通路：LVGL 正往显存画
4 -> /dev/input/event5     ← 触摸通路：GT9xx 已接入 LVGL 输入子系统
```

CPU 时间在增长（动画渲染中）。**换上屏幕，这套画面直接就出现在屏上**——软件侧没有任何事要重做。

---

## 1. 三条路线对比（为什么选第三条）

| 路线 | 需要什么 | 结论 |
|---|---|---|
| A. 课程 app_sdk_v2 | 百度网盘下载 SDK（51MB）+ 专用工具链（409MB） | 备选。源码不在本地，下载要等 |
| B. SDK 自带 lvgl-8 包走 OpenWrt 构建 | 无需下载，但要 menuconfig 开包、整个 build.sh 重编（30-40 分钟）、重烧 | 太重 |
| **C. SDK 自带 lvgl-8 源码 + 手写 Makefile 直编**（本手册） | **零下载**（源码和工具链 Tina SDK 全自带），**不重编固件**（adb push 即部署），编译 3 分钟 | ✅ 推荐 |

**关键认知：Tina SDK 里本来就藏着完整的 LVGL 8.3.2**：

| 素材 | 位置（VM） |
|---|---|
| LVGL 库源码 | `~/T113-Tina5.0-V1.2/platform/thirdparty/gui/lvgl-8/lvgl` |
| 显示/输入移植层（sunxifb/evdev） | `.../lvgl-8/lv_drivers` |
| 应用模板（main.c + 配置 + Makefile） | `.../lvgl-8/lv_examples/src/` |
| ARM 交叉编译器 gcc 8.3.0 | `.../openwrt/openwrt/staging_dir/toolchain/bin`（短名 `arm-openwrt-linux-gcc`，没有就 `ln -sf arm-openwrt-linux-gnueabi-gcc-8.3.0` 补一个） |

> 全志这套移植层的价值：`sunxifb.c` 已经替你处理了 fb0 打开、尺寸自适应（自动读到 720×1424）、32bpp 格式、双缓冲；`evdev.c` 处理触摸事件读取。**main.c 里 10 行代码就完成显示+输入注册。**

## 2. 硬件/系统事实（本关用到的）

| 项目 | 值 | 怎么确认 |
|---|---|---|
| 显存设备 | `/dev/fb0`，**32bpp**，virtual_size **720,2848**（1424×2 = 双缓冲） | `cat /sys/class/graphics/fb0/bits_per_pixel; cat .../virtual_size` |
| 分辨率 | 720×1424（FL7707 竖屏） | 考核④已配置 |
| 触摸设备 | **`/dev/input/event5`**（Name="gt9xxnew_ts"，input5） | `cat /proc/bus/input/devices` |
| 依赖 | 无（纯软件渲染，未开 G2D；demo 宏全开；`LV_COLOR_DEPTH 32`） | lv_conf.h / lv_drv_conf.h |

## 3. 三步复刻（全部命令可复制）

### 第 1 步：VM 里一键编译

一键脚本已入库：[`patches/build_lvgl.sh`](patches/build_lvgl.sh)（VM 里放 `~/build_lvgl.sh`，源码目录 `~/lvgl_kelpbar`）。

```sh
sh ~/build_lvgl.sh
# 首次全量编译约 3 分钟，结尾输出 BUILD_OK: /home/karry/lvgl_kelpbar/lv_examples
# 产物约 2.2MB，file 确认：ELF 32-bit LSB executable, ARM
```

脚本做的事：从 SDK 拷出 lvgl 库 + lv_drivers + 应用模板 → **唯一的修改**：`lv_drv_conf.h` 里 `EVDEV_NAME` 从全志默认的 `/dev/input/event3` 改成本板的 **`/dev/input/event5`** → 用交叉工具链 `make CC=arm-openwrt-linux-gcc`。

### 第 2 步：取回并推上板

```cmd
:: Windows（D:\t113_work 下）
python vm_get_b64.py /home/karry/lvgl_kelpbar/lv_examples D:/t113_work/lv_examples
MSYS_NO_PATHCONV=1 flash_tools\adb.exe push D:\t113_work\lv_examples /usr/bin/lv_examples
MSYS_NO_PATHCONV=1 flash_tools\adb.exe shell "chmod 755 /usr/bin/lv_examples"
```

> VM 的 sshd 没有 SFTP，文件传输走 base64 通道（vm_get_b64.py），见 08-bt 文档附录。

### 第 3 步：运行（5 个 demo 任选）

```sh
# 板上（建议 start-stop-daemon 后台跑，防 adb 会话断开杀进程——08-bt 的教训）
start-stop-daemon -S -b -m -p /var/run/lvgl.pid -x /usr/bin/lv_examples -- 0

# 参数：0=widgets（表单控件） 1=music（音乐播放器） 2=benchmark（性能测试）
#       3=keypad_encoder 4=stress（压力测试）
```

## 4. 验证关卡（无屏也能全查）

| # | 查什么 | 命令 | 通过标准 |
|---|---|---|---|
| 1 | 进程活着 | `cat /var/run/lvgl.pid` + `ps \| grep lv_exa` | 进程存在，状态 S |
| 2 | **显示通路** | `ls -l /proc/<pid>/fd \| grep fb0` | `3 -> /dev/fb0` |
| 3 | **触摸通路** | `ls -l /proc/<pid>/fd \| grep event` | `4 -> /dev/input/event5` |
| 4 | 在渲染 | 隔 3 秒两次 `cat /proc/<pid>/stat` 取 utime（第 14 字段） | 数字在涨（动画在画） |
| 5 | **画面内容** | 第 5 部分的 fb dump | 看到 widgets demo 完整界面 |

## 5. ★ 云看屏：fb0 dump 转图片（无屏时代的眼睛）

原理：LVGL 最终就是把像素写进 `/dev/fb0`。把显存原样拉回来，按"720 宽 × 1424 高 × 4 字节 BGRA"解码，就是屏上应有的画面。

```sh
# 板上：dump（virtual 是双缓冲 720×2848，前一半是当前显示帧）
cat /dev/fb0 > /tmp/fb.raw          # 8,202,240 字节
# Windows：拉回
adb pull /tmp/fb.raw fb_lvgl.raw
```

```python
# Windows：转 PNG（Python + Pillow）
from PIL import Image
data = open('fb_lvgl.raw','rb').read()
W,H = 720,1424
img = Image.frombytes('RGBA', (W,H), data[0:W*H*4], 'raw', 'BGRA')
img.save('lvgl_fb_dump.png')
```

> **为什么 BGRA**：fb 是 32bpp 小端，内存字节序是 B,G,R,A。dump 颜色不对（红蓝互换）就是字节序没对上。
> **换屏后这个方法依然有用**：不用对屏拍照就能留档画面证据。

## 6. ★ 换屏后一次性点亮清单（当天照着做即可）

软件侧零改动，按顺序走一遍（全程约 5 分钟）：

1. 烧录现有固件即可（v12_bt 或之后版本——**LVGL 不在固件里，靠 adb push，重烧不丢**）
2. `adb shell "cat /sys/class/graphics/fb0/virtual_size"` → 应为 `720,2848`（显示链路活着，考核④的彩条也可复验）
3. `adb shell "ls -l /usr/bin/lv_examples"` → 在（不在就重新 push，10 秒）
4. `adb shell "cat /proc/bus/input/devices | grep -A3 gt9xx"` → **复核触摸还是不是 event5**（换屏换了触摸 FPC，若 input 序号变了：改 `~/lvgl_kelpbar/lv_drv_conf.h` 的 `EVDEV_NAME` → `sh ~/build_lvgl.sh` 重编 → 重推，全程 3 分钟）
5. `start-stop-daemon -S -b -m -p /var/run/lvgl.pid -x /usr/bin/lv_examples -- 0`
6. **屏上应直接出现 widgets demo**；手指点「Gender 下拉框 / 开关 / 滑条」验证触摸
7. 想炫技再跑 `lv_examples 2`（benchmark，帧率测试）或 `lv_examples 1`（音乐播放器 demo，有动画）

**万一屏不亮**：先 `echo 1 > /sys/class/disp/disp/attr/colorbar` 看彩条出不出（考核④的验证法）——彩条出而 LVGL 不出才和 LVGL 有关；彩条也不出是新屏适配问题，回到考核④排查，与 LVGL 无关。

## 7. 踩坑档案（本关实际遇到的）

| # | 现象 | 真因 | 解法 |
|---|---|---|---|
| 1 | 课程路线的 SDK/工具链不在本地 | app_sdk_v2 和 toolchain-sunxi 只在百度网盘 | **不用下载**：Tina SDK 自带 lvgl-8 全套源码 + gcc 8.3.0 工具链 |
| 2 | VM 开机后 SSH 黑屏无 banner | 虚拟机偶发启动卡死 | `VBoxManage controlvm t113-ubuntu poweroff` → `startvm t113-ubuntu --type headless` → 等 90 秒（数据不丢） |
| 3 | `ssh` 命令行连 VM 报 Permission denied | VM 认证是**密码**不是密钥 | 用 `python ssh_run.py "命令"`（paramiko + 密码） |
| 4 | 直接 make 找不到编译器 | 工具链短名 + STAGING_DIR | PATH 加 toolchain/bin、export STAGING_DIR（同 bluealsa 编译配方） |
| 5 | 触摸按全志默认 event3 会摸不到 | 本板 GT9xx 在 event5 | lv_drv_conf.h 改 `EVDEV_NAME "/dev/input/event5"`，换屏后复核（第 6 部分 第 4 条） |

## 8. 常考问题

**Q1：屏幕坏着，你怎么证明 LVGL 真的在跑？**
A：四层证据：①进程存活（ps）；②文件描述符握着 `/dev/fb0` 和 `/dev/input/event5`（/proc/<pid>/fd）；③CPU 时间持续增长（动画在渲染）；④**把 fb0 显存 dump 出来解码成 PNG，画面完整正确**——这等价于"屏上应该显示的内容"，只是没有物理屏把它变成光。

**Q2：为什么不用课程的 app_sdk_v2？**
A：它需要网盘下载 51MB SDK + 409MB 专用工具链；而 Tina SDK 里自带的 lvgl-8（8.3.2）+ 全志移植层（sunxifb/evdev）+ 8.3.0 交叉工具链完全等价，且**不用重编固件**。课程 SDK 以后做项目应用（组件层封装、字库、动画）时再上，跑通 demo 两者无差别。

**Q3：LVGL 的显示驱动是怎么接上 fb0 的？**
A：分层：LVGL 核心只调 `flush_cb` 回调把渲染好的缓冲区交出去；全志的 `sunxifb.c` 实现这个回调——open fb0 → `FBIOGET_VSCREENINFO` 自动读尺寸 → mmap 显存 → flush 时 memcpy/pan display（双缓冲）。输入同理：LVGL 定时调 `read_cb`，`evdev.c` 从 event5 读 input_event 转成 LVGL 坐标。**核心与硬件完全解耦，这就是 LVGL 能跨平台的原因。**

**Q4：widgets demo 在 720×1424 上会不会显示不全？**
A：LVGL 控件自适应父容器尺寸，demo 会铺满实际分辨率。竖屏上半部分是内容区、下半留白是正常布局（demo 按内容排）。做自己的应用时用 `lv_disp_get_hor_res/ver_res` 取实际尺寸设计即可。

**Q5：为什么触摸换屏后可能变号？**
A：event 号按驱动 probe 顺序分配，当前板上 event0~6 共 7 个输入设备，GT9xx 排到 input5。换屏若换了触摸控制器型号/时序，枚举顺序可能变——所以点亮清单里第 4 条是复核而不是假设。

## 9. 复刻自检清单

- [ ] 我知道 LVGL 源码/移植层/工具链都在 Tina SDK 里，不用下载
- [ ] 我跑通了 `sh ~/build_lvgl.sh`（产物 ARM ELF 约 2.2MB）
- [ ] 我用 adb push 部署并后台启动了 widgets demo
- [ ] 我验证了 fd：`3 -> /dev/fb0`、`4 -> /dev/input/event5`
- [ ] 我 dump fb0 转出 PNG，看到了 widgets demo
- [ ] 我知道换屏后要复核 event 号（3 分钟重编流程）
- [ ] 我能回答"无屏怎么证明 LVGL 在跑"（四层证据）

---

*软件就绪时间：2026-10-14 ｜ 编译环境：VM t113-ubuntu（~/lvgl_kelpbar + ~/build_lvgl.sh）｜ 产物：D:\t113_work\lv_examples ＝ 板上 /usr/bin/lv_examples ｜ 对应固件：任意（不依赖固件重烧）*
