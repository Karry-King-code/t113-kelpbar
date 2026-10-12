#!/bin/bash
# ============================================================
# 音频一键部署脚本
# 把测试音频 + MP3 播放器推送到板子
#
# 用法（在 Git Bash 里执行）：
#   bash D:/t113_repos/05-speaker/patches/deploy_audio.sh
#
# 说明：
#   - 如果用的是 t113_v8_music.img（已含 madplay），只需推音频文件
#   - 如果用的是旧固件，这个脚本也会把 madplay 二进制推上去
# ============================================================

ADB="D:/t113_work/flash_tools/adb.exe"
DIR="D:/t113_repos/05-speaker/patches"

# Git Bash 里必须加这个，否则 Linux 路径会被改写成 Windows 路径
export MSYS_NO_PATHCONV=1

echo "=========================================="
echo "  音频部署脚本"
echo "=========================================="
echo

# 检查 adb 和板子
echo "[1/5] 检查 adb 连接..."
DEV=$("$ADB" devices 2>&1 | grep -c "device$")
if [ "$DEV" -eq 0 ]; then
    echo "      ❌ 没找到板子，请检查 USB 线和 adb"
    read -p "按回车退出"
    exit 1
fi
echo "      ✅ 板子已连接"
echo

echo "[2/5] 创建目录..."
"$ADB" shell "mkdir -p /root/audio"
echo "      ✅ /root/audio"
echo

echo "[3/5] 推送测试音频..."
for f in test_440.wav test_scale.wav music_twinkle.wav music_twinkle.mp3 notify.mp3; do
    if [ -f "$DIR/$f" ]; then
        printf "      %-22s " "$f"
        "$ADB" push "$DIR/$f" "/root/audio/$f" 2>&1 | grep -q "1 file pushed" && echo "✅" || echo "❌"
    fi
done
echo

echo "[4/5] 检查 MP3 播放器..."
if "$ADB" shell "which madplay" 2>/dev/null | grep -q madplay; then
    echo "      ✅ madplay 已存在（v8 固件自带）"
else
    echo "      ⚠️  固件里没有 madplay"
    echo "         请用 t113_v8_music.img 重新烧录"
    echo "         （详细方法见 doc/能播放什么音乐-实测.md）"
fi
echo

echo "[5/5] 检查音频配置..."
"$ADB" shell '
printf "      HPOUT Switch: "; amixer cget name="HPOUT Switch" 2>/dev/null | grep -o "values=.*"
printf "      HPOUT Gain  : "; amixer cget name="HPOUT Gain" 2>/dev/null | grep -oE "values=[0-9]+" | tail -1
printf "      PA_SHDN     : "; cat /sys/class/gpio/gpio34/value 2>/dev/null || echo "未设置"
'
echo

echo "=========================================="
echo "  部署完成！"
echo "=========================================="
echo
echo "测试命令："
echo "  WAV : adb shell \"aplay /root/audio/test_440.wav\""
echo "  MP3 : adb shell \"madplay /root/audio/music_twinkle.mp3\""
echo
read -p "按回车关闭窗口"
