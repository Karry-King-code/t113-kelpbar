#!/bin/sh
# ============================================================
#  蓝牙配对 agent（必须常驻，否则手机配对无人应答/音频连不上）
#
#  两个踩过的坑，都写在这里防止再犯：
#
#  坑1: bluetoothctl 启动会自动注册一个 KeyboardDisplay 的 agent，
#       对外宣称"能显示配对码"→ 对方(手机)就发起要人按确认的配对，
#       30 秒无人按 → 超时，手机报"PIN 码或密钥不正确"。
#       解法: 用 --agent NoInputNoOutput 启动参数直接指定能力
#       (NoInputNoOutput = 免输入免确认, 内核对 Just Works 自动放行)。
#       不要再用管道喂 'agent off' + 'agent xxx' —— 那些命令是异步的，
#       off 还没生效 next 就发了，顺序全乱。
#
#  坑2: 任何一次手工跑 bluetoothctl(哪怕只是诊断)都会注册自己的
#       agent 并抢走"默认 agent"角色，它一退出角色就悬空。
#       解法: 下面每 30 秒重新 default-agent 夺回角色(自愈)。
# ============================================================
LOG=/tmp/bt_agent.log

echo "=== bt_agent start $(date) ===" >> "$LOG"

{
    printf 'default-agent\n'
    printf 'pairable on\n'
    printf 'discoverable on\n'
    while true; do
        sleep 30
        # 自愈: 被别的 bluetoothctl 抢走后自动夺回
        printf 'default-agent\n'
    done
} | bluetoothctl --agent NoInputNoOutput >> "$LOG" 2>&1
