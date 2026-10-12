@echo off
title T113 MIC Record and Playback - Assessment 6
echo ================================================
echo   T113 MIC Test: Record 5s then Play back
echo   Assessment 6
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

echo [2/4] Stopping music loop (if any) + enabling paths...
"%ADB%" shell "killall aplay 2>/dev/null; killall madplay 2>/dev/null; for p in $(ps | grep 'while true' | grep -v grep | awk '{print $1}'); do kill $p 2>/dev/null; done; sleep 1; echo 34 > /sys/class/gpio/export 2>/dev/null; echo out > /sys/class/gpio/gpio34/direction 2>/dev/null; echo 0 > /sys/class/gpio/gpio34/value; amixer cset name='HPOUT Switch' 1 >/dev/null 2>&1; amixer cset name='HPOUT Gain' 7 >/dev/null 2>&1; amixer cset name='DACL Volume' 200 >/dev/null 2>&1; amixer cset name='DACR Volume' 200 >/dev/null 2>&1; amixer cset name='MIC3 Input Select' 1 >/dev/null 2>&1; amixer cset name='MIC3 Switch' 1 >/dev/null 2>&1; amixer cset name='ADC3 Gain' 19 >/dev/null 2>&1; echo       PA=0 MIC3=on"
echo.

echo [3/4] RECORDING 5 seconds - SPEAK NOW!
echo   -----------------------------------------
echo    Talk to the board. The mic is the ROUND
echo    golden part near the MIC label.
echo   -----------------------------------------
"%ADB%" shell "arecord -f S16_LE -r 16000 -c 1 -d 5 /root/audio/test_rec.wav"
echo       Recording done.
echo.

echo [4/4] PLAYING BACK what was recorded - LISTEN!
"%ADB%" shell "aplay -q /root/audio/test_rec.wav && echo       PLAYBACK_OK"
echo.
echo ================================================
echo   Heard your own voice = Assessment 6 PASSED !
echo ================================================
pause
