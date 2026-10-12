@echo off
title T113 Audio Troubleshooter
echo ================================================
echo   T113 Audio Troubleshooter
echo   (Run this if you hear NO sound)
echo ================================================
echo.

set ADB=D:\t113_work\flash_tools\adb.exe

echo [Check 1] Sound card registered?
echo   must show:  0 [audiocodec]
"%ADB%" shell "cat /proc/asound/cards"
echo.

echo [Check 2] Amplifier enable - PA_SHDN gpio34
"%ADB%" shell "cat /sys/class/gpio/gpio34/value 2>/dev/null"
echo   must be 0 = amplifier ON. 1 = shut down = NO SOUND
echo.

echo [Check 3] Mixer settings...
"%ADB%" shell "amixer cget name='HPOUT Switch' 2>/dev/null | grep ': values'"
"%ADB%" shell "amixer cget name='HPOUT Gain' 2>/dev/null | grep ': values'"
"%ADB%" shell "amixer cget name='DACL Volume' 2>/dev/null | grep ': values'"
echo   Switch must be on, Gain should be 7, Volume 200
echo.

echo [Check 4] Playback path during playing...
"%ADB%" shell "aplay -q /root/audio/test_440.wav & sleep 1; cat /sys/kernel/debug/asoc/audiocodec/2030000.codec/dapm/* 2>/dev/null | grep -E '^(DACL|DACR|HPOUT|HPOUTL_PIN|HPOUTR_PIN):' ; wait"
echo   ALL must say: On
echo.

echo [Check 5] One-shot auto-fix, then play again - LISTEN!
"%ADB%" shell "echo 34 > /sys/class/gpio/export 2>/dev/null; echo out > /sys/class/gpio/gpio34/direction 2>/dev/null; echo 0 > /sys/class/gpio/gpio34/value; amixer cset name='HPOUT Switch' 1; amixer cset name='HPOUT Gain' 7; amixer cset name='DACL Volume' 200; amixer cset name='DACR Volume' 200"
"%ADB%" shell "aplay /root/audio/test_440.wav"
echo.

echo [Check 6] Physical checks - only YOU can do these:
echo   1. Speaker plugged into CN2 connector?  2-pin 1.25mm white
echo   2. Speaker wires not broken?
echo   3. CN2 is next to the LM4871 chip on the board.
echo.
echo ================================================
echo   If Check 1-4 all good but still no sound,
echo   the problem is HARDWARE side:
echo   - speaker not plugged, or broken speaker
echo   - wrong connector
echo ================================================
pause
