@echo off
title T113 Speaker Test - Assessment 5
echo ================================================
echo   T113 Speaker Test  (Assessment 5)
echo   Just double-click. No typing needed.
echo ================================================
echo.

set ADB=D:\t113_work\flash_tools\adb.exe

echo [1/6] Checking board connection...
"%ADB%" devices 2>&1 | findstr /R /C:"device$" >nul
if errorlevel 1 (
    echo.
    echo   [ERROR] Board not found!
    echo   - Plug USB cable into DEBUG port
    echo   - Make sure board is powered on
    echo.
    pause
    exit /b 1
)
echo       OK - board connected.
echo.

echo [2/6] Waiting for sound system ready...
"%ADB%" shell "for i in 1 2 3 4 5 6 7 8; do grep -q audiocodec /proc/asound/cards 2>/dev/null && break; sleep 1; done; grep audiocodec /proc/asound/cards"
echo       OK.
echo.

echo [3/6] Checking audio files on board...
"%ADB%" shell "ls /root/audio/test_440.wav 2>/dev/null" | findstr "test_440" >nul
if errorlevel 1 (
    echo       Files missing - deploying now...
    "%ADB%" shell "mkdir -p /root/audio"
    "%ADB%" push D:\t113_repos\05-speaker\patches\test_440.wav /root/audio/test_440.wav
    "%ADB%" push D:\t113_repos\05-speaker\patches\test_scale.wav /root/audio/test_scale.wav
    "%ADB%" push D:\t113_repos\05-speaker\patches\music_twinkle.mp3 /root/audio/music_twinkle.mp3
) else (
    echo       OK - files present.
)
echo.

echo [4/6] Enabling speaker amplifier + volume...
"%ADB%" shell "echo 34 > /sys/class/gpio/export 2>/dev/null; echo out > /sys/class/gpio/gpio34/direction 2>/dev/null; echo 0 > /sys/class/gpio/gpio34/value; amixer cset name='HPOUT Switch' 1 >/dev/null 2>&1; amixer cset name='HPOUT Gain' 7 >/dev/null 2>&1; amixer cset name='DACL Volume' 200 >/dev/null 2>&1; amixer cset name='DACR Volume' 200 >/dev/null 2>&1; echo PA_SHDN=$(cat /sys/class/gpio/gpio34/value)"
echo       PA_SHDN=0 means amplifier ON (datasheet: high=shutdown).
echo.

echo [5/6] Playing WAV test tone - LISTEN! 2 sec
"%ADB%" shell "aplay /root/audio/test_440.wav"
echo.

echo [6/6] Playing MP3 music - LISTEN! 8 sec
"%ADB%" shell "madplay /root/audio/music_twinkle.mp3 2>&1 || /root/audio/madplay /root/audio/music_twinkle.mp3 2>&1 || echo MP3-skipped: this firmware has no madplay, flash t113_v8_music.img for MP3"
echo.
echo ================================================
echo   DONE!
echo.
echo   Heard sound  =  Assessment 5  PASSED !
echo   No sound     =  double-click the OTHER bat:
echo                  "Audio-Troubleshoot"
echo ================================================
pause
