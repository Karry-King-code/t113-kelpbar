@echo off
title T113 - Music Player (loops forever)
echo ================================================
echo   T113 Music Player
echo   Plays 4 songs in a loop. Close window to stop.
echo ================================================
echo.

set ADB=D:\t113_work\flash_tools\adb.exe

echo [1/4] Checking board...
"%ADB%" devices 2>&1 | findstr /R /C:"device$" >nul
if errorlevel 1 (
    echo   [ERROR] Board not found!
    pause
    exit /b 1
)
echo       OK.
echo.

echo [2/4] Stopping any previous playback...
"%ADB%" shell "killall aplay 2>/dev/null; killall madplay 2>/dev/null; for p in $(ps | grep 'while true' | grep -v grep | awk '{print $1}'); do kill $p 2>/dev/null; done; echo       done"
echo.

echo [3/4] Enabling amplifier + volume...
"%ADB%" shell "echo 34 > /sys/class/gpio/export 2>/dev/null; echo out > /sys/class/gpio/gpio34/direction 2>/dev/null; echo 0 > /sys/class/gpio/gpio34/value; amixer cset name='HPOUT Switch' 1 >/dev/null 2>&1; amixer cset name='HPOUT Gain' 7 >/dev/null 2>&1; amixer cset name='DACL Volume' 200 >/dev/null 2>&1; amixer cset name='DACR Volume' 200 >/dev/null 2>&1; echo       PA_SHDN=$(cat /sys/class/gpio/gpio34/value)  [0 = amp ON]"
echo.

echo [4/4] Playing playlist in a loop:
echo         1. Twinkle Twinkle
echo         2. Ode to Joy
echo         3. Happy Birthday
echo         4. Two Tigers
echo.
echo   --- Loops forever. Close this window to STOP. ---
echo.

"%ADB%" shell "while true; do for f in /root/audio/music_twinkle.mp3 /root/audio/music_odejoy.mp3 /root/audio/music_birthday.mp3 /root/audio/music_twotigers.mp3; do echo; echo Playing: $f; madplay -q $f; done; done"

pause
