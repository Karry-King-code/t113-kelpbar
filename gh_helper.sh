#!/bin/bash
# T113 项目 GitHub 辅助脚本
GH="/c/Users/XYT/ghtool/bin/gh.exe"
case "$1" in
  auth)   "$GH" auth login --hostname github.com --git-protocol ssh --web ;;
  create) shift; for r in "$@"; do "$GH" repo create "Karry-King-code/$r" --public --description "T113 KelpBar 嵌入式学习 - $r"; done ;;
  push)   bash /d/t113_repos/push_all.sh ;;
  *) echo "用法: gh_helper.sh {auth|create|push}"; echo "  auth   登录 GitHub（网页授权，只做一次）"; echo "  create 建仓库，如: gh_helper.sh create t113-serial t113-touch ..."; echo "  push   推送所有仓库" ;;
esac
