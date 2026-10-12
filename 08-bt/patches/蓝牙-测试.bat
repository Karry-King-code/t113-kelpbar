@echo off
title T113 Bluetooth Test - Assessment 8
echo ================================================
echo   T113 Bluetooth Test (Assessment 8)
echo ================================================
echo.

set ADB=D:\t113_work\flash_tools\adb.exe
set RKT=D:\t113_work\rtk_hciattach

echo [1/6] Checking board...
"%ADB%" devices 2>&1 | findstr /R /C:"device$" >nul
if errorlevel 1 (
    echo   [ERROR] Board not found!
    pause
    exit /b 1
)
echo       OK.
echo.

echo [2/6] Kernel BT status...
"%ADB%" shell "echo '  ttyS1 (uart1):'; ls /dev/ttyS1 2>/dev/null || echo '  MISSING!'; echo '  h5 driver:'; dmesg | grep -iE 'rtk|h5' | tail -3"
echo.

echo [3/6] Pushing rtk_hciattach tool...
"%ADB%" push "%RKT%" /usr/bin/rtk_hciattach 2>&1 | findstr /C:"pushed"
"%ADB%" shell "chmod 755 /usr/bin/rtk_hciattach"
echo       OK.
echo.

echo [4/6] Stopping old hciattach...
"%ADB%" shell "killall hciattach rtk_hciattach 2>/dev/null; killall bluetoothd 2>/dev/null; sleep 1; echo       done"
echo.

echo [5/6] Starting BT init - trying METHOD B (rtk_hciattach rtk_h5)...
echo   (this downloads firmware from /lib/firmware/rtlbt/)
"%ADB%" shell "rtk_hciattach -n -s 115200 /dev/ttyS1 rtk_h5 > /tmp/btinit.log 2>&1 &"
echo   waiting for hci0 (up to 20s)...
"%ADB%" shell "for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do [ -d /sys/class/bluetooth/hci0 ] && break; sleep 1; done; if [ -d /sys/class/bluetooth/hci0 ]; then echo '  *** hci0 CREATED! ***'; else echo '  hci0 NOT found - see log:'; cat /tmp/btinit.log | tail -8; fi"
echo.

echo [6/6] Chip info + make discoverable...
"%ADB%" shell "hciconfig -a 2>/dev/null | head -12; echo '---'; hciconfig hci0 up piscan 2>&1; echo '---'; hciconfig hci0 | head -3"
echo.
echo ================================================
echo   Now check your PHONE Bluetooth list!
echo   The board should appear as a new device.
echo   (Name may be 'BlueZ' or similar)
echo ================================================
pause
