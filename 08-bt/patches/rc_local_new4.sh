# Put your custom commands here that should be executed once
# the system init finished. By default this file does nothing.

# ---------- 等音频子系统就绪 ----------
# 时序陷阱: rc.local 执行时声卡可能还没注册完,
# 此时 amixer 写入会被静默丢弃(读到 1), 必须等 /proc/asound/cards 出现
for i in 1 2 3 4 5 6 7 8 9 10; do
    if [ -s /proc/asound/cards ] && grep -q audiocodec /proc/asound/cards 2>/dev/null; then
        break
    fi
    sleep 1
done

# ---------- 音频：耳机/喇叭输出使能 + 音量 ----------
amixer cset name="HPOUT Switch" 1
# HPOUT Gain: 0~7 档，每档 6dB (0=-42dB, 7=0dB)。出厂 3(-24dB) 偏小，提到 7(0dB)
amixer cset name='HPOUT Gain' 7
# DAC 音量(0~255)，出厂 160；提到 200 让喇叭更响
amixer cset name='DACL Volume' 200
amixer cset name='DACR Volume' 200

# capture (MIC)
amixer -Dhw:audiocodec cset name='MIC3 Input Select' 1
amixer -Dhw:audiocodec cset name='MIC3 Switch' 1
amixer -Dhw:audiocodec cset name='ADC3 Gain' 19

# ---------- 音频：喇叭功放 LM4871 使能 (PA_SHDN = PB2 = gpio34) ----------
# 原理图第5页：HPOUTR -> R136 -> LM4871 -> CN2 喇叭座
# ★数据手册(TI)实锤: LM4871 SHUTDOWN 高电平=关断, 低电平=工作
# R138(100k) 下拉默认=开; 这里显式拉低确保开(曾误拉高导致无声)
if [ ! -d /sys/class/gpio/gpio34 ]; then
    echo 34 > /sys/class/gpio/export
fi
echo out > /sys/class/gpio/gpio34/direction
echo 0   > /sys/class/gpio/gpio34/value

# ---------- 显示：彩条 ----------
for i in 1 2 3 4 5; do
    if [ -e /sys/class/disp/disp/attr/colorbar ]; then
        break
    fi
    sleep 1
done
echo 1 > /sys/class/disp/disp/attr/colorbar


# ---------- 蓝牙开机自启 ----------
# RTL8723DS 蓝牙: UART1(ttyS1) H5 协议 + 固件下载
# 注意: 固件下载需要芯片处于冷启动状态, 所以放开机脚本里最合适
# bt_up.sh 内部还会: 起 bluetoothd -C、配置可发现/免密配对、
# 把 SPP 串口服务注册到 SDP 通道 3
# 脚本随固件打包在 /etc 下(烧录后自动就有), 所以优先用 /etc/; /root/ 是手动位置
BTUP=/etc/bt_up.sh
[ -x "$BTUP" ] || BTUP=/root/bt_up.sh
if [ -x "$BTUP" ]; then
    sh "$BTUP" > /tmp/bt_boot.log 2>&1 &
fi

# ---------- 蓝牙 SPP 串口服务(业务演示) ----------
# 电脑/手机连上后, 板子会主动问好, 并把收到的每一行回显回去
# 参数 auto = 自己挑一个没被占用的 /dev/rfcommN
# (被 kill 过的 rfcomm 会残留内核占位, 用固定编号会报 Address already in use)
# 用 start-stop-daemon -b 脱离 rc.local 进程组, 避免随初始化脚本结束一起被杀
SPPD=/etc/spp_demo2.sh
[ -x "$SPPD" ] || SPPD=/root/spp_demo2.sh
if [ -x "$SPPD" ]; then
    # 清掉可能残留的 pidfile: 否则 start-stop-daemon 会以为"已在运行"而拒绝启动
    rm -f /var/run/spp.pid
    start-stop-daemon -S -b -m -p /var/run/spp.pid \
        -x /bin/sh -- "$SPPD" auto 3
fi

exit 0
