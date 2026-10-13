#!/bin/sh
# T113 蓝牙一键启动脚本
# 用法: sh /root/bt_up.sh
# 前提: 板子刚冷启动(拔线上电), 芯片状态新鲜

echo "=== [1/3] 清理旧状态 ==="
killall -9 rtk_hciattach hciattach bluetoothd bluetoothctl 2>/dev/null
sleep 1
rm -rf /var/lib/bluetooth/* 2>/dev/null
echo "已清理(含旧配对记录)"

echo "=== [2/3] 启动 HCI 链路(固件下载) ==="
rtk_hciattach -n -s 115200 /dev/ttyS1 rtk_h5 > /tmp/bt.log 2>&1 &

i=0
while [ ! -d /sys/class/bluetooth/hci0 ]; do
    sleep 1
    i=$((i+1))
    if [ $i -gt 40 ]; then
        echo "*** hci0 超时! 日志尾部: ***"
        tail -6 /tmp/bt.log
        exit 1
    fi
done
echo "hci0 已创建 (用时 ${i}s)"

echo "=== [3/3] 配置(免密配对+可发现) ==="
btmgmt power on         2>&1 | tail -1
btmgmt ssp on           2>&1 | tail -1
btmgmt io-cap 3         2>&1 | tail -1
btmgmt connectable on   2>&1 | tail -1
btmgmt name T113-KelpBar 2>&1 | tail -1
hciconfig hci0 class 0x000104
hciconfig hci0 piscan
sleep 1

echo
echo "===== 最终状态 ====="
btmgmt info 2>&1 | grep -E 'current settings|name'
hciconfig hci0 | head -3
echo "====================="
echo "READY"
