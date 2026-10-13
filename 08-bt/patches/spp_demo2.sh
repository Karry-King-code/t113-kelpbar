#!/bin/sh
# ============================================================
#  蓝牙 SPP 串口服务(业务演示) v3
#  用法: sh /root/spp_demo2.sh [auto|/dev/rfcommN] [channel]
#
#  作用: 监听蓝牙 Serial Port 服务(默认通道 3), 对方连上后
#        1) 板子主动发两行问候
#        2) 对方发什么, 板子回 "T113-Echo: <原文>"
#        连接/收发/断开都记到 /tmp/spp_events.log
#
#  两个设计要点(踩过的坑):
#   a) 本板 BlueZ 的 "rfcomm listen <dev> <ch> <cmd>" 钩子不会真执行
#      cmd, 所以拆成两半: rfcomm 负责建 tty, 本循环负责收发。
#   b) /sys/class/tty/rfcommN 存在 == 内核里 dev id N 已被占用。
#      被 kill 掉过的 rfcomm 进程会残留这个占位, 导致再连时报
#      "Can't create RFCOMM TTY: Address already in use"。
#      所以 auto 模式会跳过这些已被占用的编号。
#      彻底清干净的办法是重启板子(内核态在内存里)。
#
#  用 -r(--raw) 让 tty 不进 line discipline: 关掉回显, 否则对方
#  发的字节会被原样弹回去(还带出 ^J 这类控制符)。本板没有 stty。
# ============================================================
DEV=${1:-auto}
CH=${2:-3}
LOG=/tmp/spp_events.log

pick_dev() {
    i=0
    while [ $i -lt 32 ]; do
        if [ ! -e "/sys/class/tty/rfcomm$i" ]; then
            echo "/dev/rfcomm$i"
            return 0
        fi
        i=$((i + 1))
    done
    echo "/dev/rfcomm0"
}
[ "$DEV" = "auto" ] && DEV=$(pick_dev)

# 开机自启时 rc.local 会立刻调用本脚本, 此时 hci0 可能还没就绪
i=0
while [ ! -e /sys/class/bluetooth/hci0 ] && [ $i -lt 60 ]; do
    sleep 1
    i=$((i + 1))
done

echo "=== spp_demo2 start $(date) dev=$DEV ch=$CH ===" >> "$LOG"

while true; do
    rfcomm -r listen "$DEV" "$CH" >/dev/null 2>&1 &
    LPID=$!

    # 等对方连上(tty 出现); 若监听进程自己先退出(比如 hci0 还没好)就重来
    n=0
    while [ ! -c "$DEV" ] && [ $n -lt 1800 ]; do
        sleep 1
        n=$((n + 1))
        kill -0 $LPID 2>/dev/null || break
    done

    if [ -c "$DEV" ]; then
        echo "CONNECTED $(date)" >> "$LOG"
        if exec 3<> "$DEV" 2>/dev/null; then
            printf '*** T113-KelpBar BT SPP connected ***\n' >&3
            printf 'T113: echo server ready, send any line\n' >&3
            while IFS= read -r line <&3; do
                echo "RX: $line" >> "$LOG"
                printf 'T113-Echo: %s\n' "$line" >&3
            done
            exec 3<&-
        else
            echo "open $DEV failed" >> "$LOG"
        fi
        echo "DISCONNECTED $(date)" >> "$LOG"
    else
        echo "listener exited / no peer, retry ($DEV)" >> "$LOG"
    fi

    kill $LPID 2>/dev/null
    sleep 2
done
