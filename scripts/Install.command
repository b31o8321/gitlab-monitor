#!/bin/bash
# Internal-distribution installer for GitLabMonitor.
# Copies the app to /Applications, clears macOS quarantine, and launches it.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SRC="$DIR/GitLabMonitor.app"
APP_DEST="/Applications/GitLabMonitor.app"

echo "==> 安装 GitLabMonitor / Installing GitLabMonitor"
echo ""

if [[ ! -d "$APP_SRC" ]]; then
    echo "找不到 / Cannot find: $APP_SRC"
    echo "请确认本脚本与 GitLabMonitor.app 在同一目录 / Make sure this script sits next to GitLabMonitor.app"
    read -n 1 -s -r -p "按任意键退出 / Press any key to exit..."
    exit 1
fi

if pgrep -x GitLabMonitor > /dev/null; then
    echo "停止运行中的实例 / Stopping running instance..."
    pkill -x GitLabMonitor || true
    sleep 1
fi

if [[ -d "$APP_DEST" ]]; then
    echo "移除旧版本 / Removing old version..."
    rm -rf "$APP_DEST"
fi

echo "复制到 /Applications / Copying to /Applications..."
cp -R "$APP_SRC" "$APP_DEST"

echo "清除 macOS 隔离属性 / Clearing macOS quarantine attribute..."
xattr -cr "$APP_DEST"

echo "启动 / Launching..."
open "$APP_DEST"

echo ""
echo "完成 / Done. 菜单栏应出现 GitLab 图标 / GitLab icon should now be in your menu bar."
echo ""
sleep 3
