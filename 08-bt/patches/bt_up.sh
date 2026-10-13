#!/bin/sh
# T113 蓝牙一键启动脚本 (RTL8723DS / UART1 ttyS1 / H5 协议)
# 用法: sh /root/bt_up.sh [clean]
#   clean = 先清空配对记录(只有配对反复出问题时才加, 平时不要加)
# 开机时由 /etc/rc.local 自动调用(不带参数), 所以正常重启不会丢配对记录
# 前提: 固件下载要求芯片处于新鲜状态, 所以这一步放在开机脚本里最合适

step() { echo; echo "=== $* ==="; }

step "[1/6] 清理残留的 attach 进程"
# 只杀 hciattach 系, 不杀 bluetoothd / bluealsa —— 下面还要用它们
killall -9 rtk_hciattach hciattach 2>/dev/null
sleep 1
if [ "$1" = "clean" ]; then
    rm -rf /var/lib/bluetooth/*
    echo "已清空配对记录"
else
    echo "保留配对记录 (需要清空请执行: sh /root/bt_up.sh clean)"
fi

step "[2/6] 启动 HCI 链路(含固件下载)"
rtk_hciattach -n -s 115200 /dev/ttyS1 rtk_h5 > /tmp/bt.log 2>&1 &

i=0
while [ ! -d /sys/class/bluetooth/hci0 ]; do
    sleep 1
    i=$((i + 1))
    if [ $i -gt 40 ]; then
        echo "*** hci0 超时(40s)! 日志尾部: ***"
        tail -6 /tmp/bt.log
        exit 1
    fi
done
echo "hci0 已创建 (用时 ${i}s)"

step "[3/6] 启动 bluetoothd (必须带 -C)"
# -C = 兼容模式; 不带它 /var/run/sdp 这个 socket 不会生成,
#      后面 sdptool 会报 Failed to connect to SDP server
if ps w | grep '[b]luetoothd' > /dev/null; then
    echo "bluetoothd 已在运行"
else
    bluetoothd -n -C > /tmp/bluetoothd.log 2>&1 &
    echo "已启动 bluetoothd -n -C"
fi

i=0
while [ ! -S /var/run/sdp ] && [ $i -lt 20 ]; do
    sleep 1
    i=$((i + 1))
done
if [ -S /var/run/sdp ]; then echo "SDP socket 就绪"; else echo "SDP socket 未出现(sdptool 可能失败)"; fi

step "[4/6] 配置(可发现 + 可配对 + 免密)"
btmgmt power on          2>&1 | tail -1
# ssp on + io-cap 3 = 免输入配对码, 否则会和旧配对记录打架报"配对码不匹配"
btmgmt ssp on            2>&1 | tail -1
btmgmt io-cap 3          2>&1 | tail -1
# bondable on 必须设, 否则对方点配对会被直接拒绝
btmgmt bondable on       2>&1 | tail -1
btmgmt connectable on    2>&1 | tail -1
btmgmt discoverable on   2>&1 | tail -1
btmgmt name T113-KelpBar 2>&1 | tail -1
# 设备类别必须设(0x000104), 否则安卓/Windows 会搜不到或归类错误
hciconfig hci0 class 0x000104
hciconfig hci0 piscan

step "[5/6] 启动蓝牙音箱服务 A2DP Sink (手机显示'已连接'靠它)"
# 安卓的设置界面只对音频/输入类 profile 显示"已连接", 串口(SPP)不算,
# 所以想让手机显示"已连接", 就需要这条 A2DP Sink 通路。
# 注意: 显示"已连接"并不要求喇叭接线, 只有要听声音才需要接喇叭。
if ps w | grep '[b]luealsa ' > /dev/null; then
    echo "bluealsa 已在运行"
else
    bluealsa -p a2dp-sink --a2dp-volume -i hci0 > /tmp/bluealsa.log 2>&1 &
    echo "已启动 bluealsa -p a2dp-sink"
fi

sleep 1

if ps w | grep '[b]luealsa-aplay' > /dev/null; then
    echo "bluealsa-aplay 已在运行"
else
    bluealsa-aplay --profile-a2dp 00:00:00:00:00:00 > /tmp/bluealsa_aplay.log 2>&1 &
    echo "已启动 bluealsa-aplay (把收到的音频送到声卡)"
fi

step "[6/6] 注册 SPP 串口服务到 SDP(通道 3)"
# SDP 记录只存在 bluetoothd 内存里, 每次开机都要重新注册
# (A2DP / AVRCP 的记录由 bluealsa 自己注册, 不用管)
sdptool del 0x10003 > /dev/null 2>&1
sdptool add --channel=3 SP > /tmp/sdp.log 2>&1
cat /tmp/sdp.log 2>/dev/null

echo
echo "===== 最终状态 ====="
btmgmt info 2>&1 | grep -E 'current settings|name'
hciconfig hci0 | head -3
echo "--- SDP 服务列表 ---"
sdptool browse local 2>&1 | grep 'Service Name' 
echo "--- 关键进程 ---"
ps w | grep -E '[b]luetoothd|[b]luealsa|[r]tk_hciattach' | sed 's/^/  /'
echo "====================="
echo "READY"
