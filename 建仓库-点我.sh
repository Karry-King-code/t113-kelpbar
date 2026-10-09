#!/bin/bash
# 如果这一步失败，说明需要用网页建仓库：
# https://github.com/new
echo "请用浏览器打开 https://github.com/new"
echo "依次创建这 5 个空仓库（不要勾任何选项）："
echo "  t113-serial"
echo "  t113-led-key"
echo "  t113-touch"
echo "  t113-display"
echo "  t113-overview"
echo
cmd.exe /c start https://github.com/new 2>/dev/null || start https://github.com/new
