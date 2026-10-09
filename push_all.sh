#!/bin/bash
# ============================================================
# T113 节点仓库一键推送脚本
# 用法：在 Git Bash 里执行  bash D:/t113_repos/push_all.sh
# 前提：已在 GitHub 网页上建好 5 个空仓库（见下方清单）
# ============================================================

set -u
REPOS="/d/t113_repos"

echo "=========================================="
echo " T113 节点仓库一键推送"
echo "=========================================="
echo

# 先验证 SSH 通不通
echo "[1/3] 验证 GitHub 认证..."
AUTH=$(ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes -T git@github.com 2>&1)
if echo "$AUTH" | grep -q "successfully authenticated"; then
    echo "      ✅ $AUTH"
else
    echo "      ❌ 认证失败：$AUTH"
    echo "      请检查 ~/.ssh/id_ed25519 是否存在"
    exit 1
fi
echo

echo "[2/3] 开始推送 5 个仓库..."
echo
FAIL=0
for d in "$REPOS/01-serial" "$REPOS/02-led-key" "$REPOS/03-touch" "$REPOS/04-display" "$REPOS"; do
    name=$(basename "$d")
    [ "$name" = "t113_repos" ] && name="总览(t113-overview)"
    printf "  %-24s " "$name"
    out=$(cd "$d" && timeout 120 git push -u origin main 2>&1)
    if echo "$out" | grep -qE "branch 'main' set up|new branch|Everything up-to-date"; then
        echo "✅ 推送成功"
    else
        echo "❌ 失败"
        echo "$out" | grep -E "ERROR|fatal|error" | head -3 | sed 's/^/       /'
        FAIL=$((FAIL+1))
    fi
done
echo

echo "[3/3] 结果"
if [ "$FAIL" -eq 0 ]; then
    echo "  🎉 全部 5 个仓库推送完成！浏览器打开查看："
    echo "     https://github.com/Karry-King-code?tab=repositories"
else
    echo "  ⚠️  有 $FAIL 个仓库推送失败，请看上面的错误信息"
    echo "     最常见原因：网页上还没建对应的空仓库"
fi
