#!/bin/sh
# ============================================================
#  蓝牙配对 agent（必须常驻，否则手机连不上音频）
#
#  为什么需要它：
#  板子上跑着 bluetoothd，手机来连接时它要找人"确认"这次鉴权。
#  没有 agent 时 bluetoothd 的日志是：
#      Authentication attempt without agent
#      Access denied: org.bluez.Error.Rejected
#  于是无论串口还是音频都被直接拒掉。
#
#  串口(SPP)之所以之前能连上，是因为 rfcomm 监听没要求鉴权；
#  而音频(A2DP)必须走鉴权，所以"手机连不上、只是已保存"。
#
#  NoInputNoOutput = 不需要在两端输入/确认配对码（Just Works），
#  配合 btmgmt 的 ssp on + io-cap 3，手机点一下就直接配上。
#
#  启动后 bluetoothd 会把配对密钥写进 /var/lib/bluetooth/，
#  这个目录在 overlay 上（可写分区），所以重启不会丢。
# ============================================================
LOG=/tmp/bt_agent.log

echo "=== bt_agent start $(date) ===" >> "$LOG"

{
    printf 'agent NoInputNoOutput\n'
    printf 'default-agent\n'
    printf 'pairable on\n'
    printf 'discoverable on\n'
    # 一直占住这句管道的读端，bluetoothctl 才不会退出；
    # bluetoothctl 一退出，agent 注册就没了，蓝牙连接又会被拒。
    while true; do
        sleep 3600
    done
} | bluetoothctl >> "$LOG" 2>&1
