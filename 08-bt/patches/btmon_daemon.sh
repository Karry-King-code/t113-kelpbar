#!/bin/sh
# btmon 抓包守护: nohup 没有、`&` 随 adb 会话死, 所以用 setsid? 也没有。
# start-stop-daemon -b 会把 stdout 指到 /dev/null, 所以 btmon 用自己的 -w 写二进制,
# 平时看就用 btmon -r 读。
killall -9 btmon 2>/dev/null
sleep 1
rm -f /var/run/btmon.pid /tmp/btmon_cap.btsnoop
start-stop-daemon -S -b -m -p /var/run/btmon.pid -x /usr/bin/btmon -- -w /tmp/btmon_cap.btsnoop
sleep 2
ps w | grep '[b]tmon'
ls -l /tmp/btmon_cap.btsnoop 2>&1
echo "抓包中。看内容: btmon -r /tmp/btmon_cap.btsnoop | grep -E 'Pair|Failed|Reject|Encrypt|Connect'"
