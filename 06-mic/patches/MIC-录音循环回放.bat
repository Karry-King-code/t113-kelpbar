@echo off
title T113 MIC Record - then LOOP playback
echo ================================================
echo   T113 MIC Test - Record once, LOOP forever
echo   Close this window to stop the loop.
echo ================================================
echo.

set ADB=D:\t113_work\flash_tools\adb.exe

echo [1/5] Checking board...
"%ADB%" devices 2>&1 | findstr /R /C:"device$" >nul
if errorlevel 1 (
    echo   [ERROR] Board not found!
    pause
    exit /b 1
)
echo       OK.
echo.

echo [2/5] Stopping music loop + enabling MIC and speaker...
"%ADB%" shell "killall aplay 2>/dev/null; killall madplay 2>/dev/null; for p in $(ps | grep 'while true' | grep -v grep | awk '{print $1}'); do kill $p 2>/dev/null; done; sleep 1; echo 34 > /sys/class/gpio/export 2>/dev/null; echo out > /sys/class/gpio/gpio34/direction 2>/dev/null; echo 0 > /sys/class/gpio/gpio34/value; amixer cset name='HPOUT Switch' 1 >/dev/null 2>&1; amixer cset name='HPOUT Gain' 7 >/dev/null 2>&1; amixer cset name='DACL Volume' 200 >/dev/null 2>&1; amixer cset name='DACR Volume' 200 >/dev/null 2>&1; amixer cset name='MIC3 Input Select' 1 >/dev/null 2>&1; amixer cset name='MIC3 Switch' 1 >/dev/null 2>&1; amixer cset name='ADC3 Gain' 19 >/dev/null 2>&1; echo       ready"
echo.

echo [3/5] Get ready... recording starts in:
ping -n 2 127.0.0.1 >nul
echo    3...
ping -n 2 127.0.0.1 >nul
echo    2...
ping -n 2 127.0.0.1 >nul
echo    1...
ping -n 2 127.0.0.1 >nul
echo.

echo [4/5] ============  SPEAK NOW ! ! !  ============
echo    (talk to the round golden mic, 5 seconds)
echo.
"%ADB%" shell "arecord -f S16_LE -r 16000 -c 1 -d 5 /root/audio/test_rec.wav" >nul 2>&1
echo       Recording done. Your voice was saved.
echo.

echo [5/5] LOOPING PLAYBACK - listen!
echo   --- repeats forever until you close this window ---
echo.
"%ADB%" shell "while true; do aplay -q /root/audio/test_rec.wav; sleep 1; done"

pause
