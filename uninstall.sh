#!/bin/sh
# 移除 mac-dont-sleep，恢復成闔蓋就睡。舊名稱 lid-sleep-by-power 的安裝也一起移除。
# 用法：sudo sh uninstall.sh

if [ "$(id -u)" != 0 ]; then
  echo "請用 sudo 執行：sudo sh $0" >&2
  exit 1
fi

for name in mac-dont-sleep lid-sleep-by-power; do
  launchctl bootout system/local.$name 2>/dev/null
  rm -f /Library/LaunchDaemons/local.$name.plist /usr/local/bin/$name.sh
done
pmset -a disablesleep 0
echo "已移除。"
pmset -g | grep SleepDisabled
