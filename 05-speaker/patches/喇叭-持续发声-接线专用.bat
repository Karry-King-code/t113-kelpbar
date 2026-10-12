@echo off
title T113 Speaker - CONTINUOUS tone for wiring
echo ================================================
echo   T113 Speaker - CONTINUOUS sound
echo   Sound plays UNTIL you close this window!
echo ================================================
echo.

set ADB=D:\t113_work\flash_tools\adb.exe

echo [1/3] Checking board...
"%ADB%" devices 2>&1 | findstr /R /C:"device$" >nul
if errorlevel 1 (
    echo   [ERROR] Board not found!
    pause
    exit /b 1
)
echo       OK.
echo.

echo [2/3] Enabling amplifier + volume...
"%ADB%" shell "echo 34 > /sys/class/gpio/export 2>/dev/null; echo out > /sys/class/gpio/gpio34/direction 2>/dev/null; echo 0 > /sys/class/gpio/gpio34/value; amixer cset name='HPOUT Switch' 1 >/dev/null 2>&1; amixer cset name='HPOUT Gain' 7 >/dev/null 2>&1; amixer cset name='DACL Volume' 200 >/dev/null 2>&1; amixer cset name='DACR Volume' 200 >/dev/null 2>&1; echo PA_SHDN=$(cat /sys/class/gpio/gpio34/value)"
echo.

echo [3/3] Sound is ON now - go touch the wires!
echo.
echo   --- Sound loops forever until you close this window ---
echo.
echo   Wiring:
echo   - male pins  = into SPEAK socket (2 holes)
echo   - other end  = touch speaker terminals
echo   - wires must NOT touch EACH OTHER
echo.
echo ================================================
"%ADB%" shell "while true; do aplay -q /root/audio/test_440.wav; done"
pause
