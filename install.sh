#!/bin/sh
# 安裝或更新 mac-dont-sleep。重跑一次就能換設定。
set -e

LABEL=local.mac-dont-sleep
BIN=/usr/local/bin/mac-dont-sleep.sh
PLIST=/Library/LaunchDaemons/$LABEL.plist

INTERVAL=5
WHEN=ac

usage() {
  cat <<'EOF'
用法：sudo sh install.sh [--when 條件] [--interval 秒數]

  --when 條件      什麼情況下闔蓋不睡（預設 ac）
                     ac              插著電源
                     display         接著外接螢幕（僅 Apple Silicon）
                     ac-and-display  插著電源，而且接著外接螢幕
                     ac-or-display   插著電源，或接著外接螢幕
  --interval 秒數  多久檢查一次（預設 5，最小 1）
  -h, --help       顯示這段說明

不帶參數就是預設：插著電源時闔蓋不睡，每 5 秒檢查一次。
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --when)       WHEN=${2-}; shift; [ $# -gt 0 ] && shift ;;
    --when=*)     WHEN=${1#*=}; shift ;;
    --interval)   INTERVAL=${2-}; shift; [ $# -gt 0 ] && shift ;;
    --interval=*) INTERVAL=${1#*=}; shift ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "不認得的參數：$1" >&2; usage >&2; exit 1 ;;
  esac
done

case "$WHEN" in
  ac|display|ac-and-display|ac-or-display) ;;
  *) echo "--when 只接受 ac、display、ac-and-display、ac-or-display，收到：$WHEN" >&2; exit 1 ;;
esac
case "$INTERVAL" in
  ''|*[!0-9]*) echo "--interval 要是正整數，收到：$INTERVAL" >&2; exit 1 ;;
esac
if [ "$INTERVAL" -lt 1 ]; then
  echo "--interval 最小是 1，收到：$INTERVAL" >&2; exit 1
fi

if [ "$(id -u)" != 0 ]; then
  echo "請用 sudo 執行：sudo sh $0 $*" >&2
  exit 1
fi

# 移除舊名稱 lid-sleep-by-power 的安裝。
if [ -f /Library/LaunchDaemons/local.lid-sleep-by-power.plist ]; then
  launchctl bootout system/local.lid-sleep-by-power 2>/dev/null || true
  rm -f /Library/LaunchDaemons/local.lid-sleep-by-power.plist /usr/local/bin/lid-sleep-by-power.sh
  echo "已移除舊名稱 lid-sleep-by-power 的安裝。"
fi

mkdir -p /usr/local/bin
install -m 755 "$(dirname "$0")/mac-dont-sleep.sh" "$BIN"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$BIN</string></array>
  <key>EnvironmentVariables</key><dict>
    <key>MAC_DONT_SLEEP_WHEN</key><string>$WHEN</string>
  </dict>
  <key>StartInterval</key><integer>$INTERVAL</integer>
  <key>RunAtLoad</key><true/>
</dict></plist>
EOF
chown root:wheel "$PLIST"
chmod 644 "$PLIST"

launchctl bootout system/$LABEL 2>/dev/null || true
launchctl bootstrap system "$PLIST"

sleep 2
echo "已安裝：--when $WHEN --interval $INTERVAL"
echo "目前狀態："
pmset -g ps | head -1
pmset -g | grep SleepDisabled
