#!/bin/bash
# ============================================================
# T113 节点仓库一键推送
# 用法：在 Git Bash 里执行  bash D:/t113_repos/push_all.sh
# ============================================================

echo "=========================================="
echo "  T113 节点仓库一键推送"
echo "=========================================="
echo

echo "[1/3] 验证 GitHub 认证..."
AUTH=$(ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes -T git@github.com 2>&1)
if echo "$AUTH" | grep -q "successfully authenticated"; then
    echo "      OK  $AUTH"
else
    echo "      失败：$AUTH"
    echo "      请确认 ~/.ssh/id_ed25519 存在"
    read -p "按回车退出"
    exit 1
fi
echo

echo "[2/3] 推送 5 个仓库..."
echo
OK=0
FAIL=0
for d in /d/t113_repos/01-serial /d/t113_repos/02-led-key /d/t113_repos/03-touch /d/t113_repos/04-display /d/t113_repos; do
    name=$(basename "$d")
    [ "$name" = "t113_repos" ] && name="t113-overview(总览)"
    printf "  %-22s " "$name"
    out=$(cd "$d" && timeout 180 git push -u origin main 2>&1)
    if echo "$out" | grep -qiE "new branch|set up to track|up-to-date|-> main"; then
        echo "成功"
        OK=$((OK+1))
    else
        echo "失败"
        echo "$out" | grep -iE "ERROR|fatal|error" | head -2 | sed 's/^/         /'
        FAIL=$((FAIL+1))
    fi
done
echo
echo "[3/3] 结果"
echo "  成功 $OK 个，失败 $FAIL 个"
if [ "$FAIL" -eq 0 ]; then
    echo
    echo "  全部完成！打开浏览器查看："
    echo "  https://github.com/Karry-King-code?tab=repositories"
else
    echo
    echo "  失败原因最常见的是：网页上还没建对应的空仓库"
    echo "  去 https://github.com/new 建，名字要完全一致"
fi
echo
read -p "按回车关闭窗口"
