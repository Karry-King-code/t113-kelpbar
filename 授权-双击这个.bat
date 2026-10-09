@echo off
chcp 65001 >nul
title GitHub 授权 - 按提示操作
echo ============================================
echo   GitHub 授权（只做一次）
echo ============================================
echo.
echo 接下来会出现一个授权码，形如 ABCD-1234
echo 记住它，然后按回车打开浏览器
echo.
echo ============================================
echo.
C:\Users\XYT\ghtool\bin\gh.exe auth login --hostname github.com --git-protocol ssh --web
echo.
echo ============================================
if %errorlevel%==0 (
  echo   授权成功！回来告诉 AI 一声，他会自动建仓库+推送
) else (
  echo   授权失败或有中断，把上面的信息截图发给 AI
)
echo ============================================
pause
