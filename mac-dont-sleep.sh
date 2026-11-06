#!/bin/sh
# 由 launchd 定時執行。條件成立時闔蓋不睡；條件不成立而且已經闔蓋，就讓系統入睡。
# 條件由環境變數 MAC_DONT_SLEEP_WHEN 決定，install.sh 會把它寫進 launchd 設定。

WHEN=${MAC_DONT_SLEEP_WHEN:-ac}

on_ac() {
  pmset -g ps | head -1 | grep -q "AC Power"
}

# Apple Silicon 上每個顯示器各有一個 DCPAVServiceProxy，外接的那個 Location 是 External。
has_external_display() {
  ioreg -r -c DCPAVServiceProxy -d 1 | grep -q '"Location" = "External"'
}

case "$WHEN" in
  ac)             on_ac ;;
  display)        has_external_display ;;
  ac-and-display) on_ac && has_external_display ;;
  ac-or-display)  on_ac || has_external_display ;;
  *) echo "mac-dont-sleep: 不認得的 MAC_DONT_SLEEP_WHEN：$WHEN" >&2; exit 1 ;;
esac
if [ $? = 0 ]; then want=1; else want=0; fi

cur=$(pmset -g | awk '/SleepDisabled/{print $2}')
# disablesleep 是非同步生效的，改完等 1 秒，避免緊接著的 sleepnow 被拒。
[ "$cur" != "$want" ] && pmset -a disablesleep "$want" && sleep 1

# 闔蓋時把 disablesleep 改回 0，macOS 不會重新判斷闔蓋狀態，所以要自己叫它睡。
lid=$(ioreg -r -k AppleClamshellState -d 4 | awk '/AppleClamshellState/{print $NF; exit}')
[ "$want" = 0 ] && [ "$lid" = "Yes" ] && pmset sleepnow
exit 0
