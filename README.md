# mac-dont-sleep

讓 MacBook 在你指定的條件下闔蓋不睡，條件不成立時闔蓋照常睡。預設條件是插著電源。

不帶任何參數安裝時：

| 情境 | 結果 |
|---|---|
| 插著電源 → 闔蓋 | 不睡 |
| 插著電源 → 闔蓋 → 拔除電源 | 5 秒內入睡 |
| 沒插電源 → 闔蓋 | 照常入睡 |

不需要外接螢幕或外接鍵盤滑鼠。

## 安裝

```sh
sudo sh install.sh
```

安裝完會印出目前的設定、電源來源與 `SleepDisabled`。條件成立時 `SleepDisabled` 應該是 `1`。

## 選項

```sh
sudo sh install.sh [--when 條件] [--interval 秒數]
```

| 選項 | 說明 | 預設 |
|---|---|---|
| `--when 條件` | 什麼情況下闔蓋不睡，可選值見下表 | `ac` |
| `--interval 秒數` | 多久檢查一次，正整數，最小 1 | `5` |

`--when` 的可選值：

| 值 | 闔蓋不睡的條件 |
|---|---|
| `ac` | 插著電源 |
| `display` | 接著外接螢幕，不論有沒有插電 |
| `ac-and-display` | 插著電源，而且接著外接螢幕 |
| `ac-or-display` | 插著電源，或接著外接螢幕 |

要換設定，帶新參數重跑一次 `install.sh` 就好，不用先移除。例如：

```sh
# 只有接著外接螢幕時闔蓋不睡，每 10 秒檢查一次
sudo sh install.sh --when display --interval 10
```

## 移除

```sh
sudo sh uninstall.sh
```

移除後 `SleepDisabled` 會設回 `0`，恢復成闔蓋就睡。舊名稱 `lid-sleep-by-power` 的安裝也會一起移除。

## 運作方式

pmset 的 `disablesleep` 是全系統的開關，沒辦法只在某個條件下生效。所以這裡用一個 root 的 launchd daemon 定時檢查條件，再切換 `disablesleep`。

`install.sh` 安裝兩個檔案：

- `/usr/local/bin/mac-dont-sleep.sh`：檢查腳本，從專案裡的 `mac-dont-sleep.sh` 複製過去。
- `/Library/LaunchDaemons/local.mac-dont-sleep.plist`：launchd 設定。`--interval` 寫進 `StartInterval`，`--when` 寫進環境變數 `MAC_DONT_SLEEP_WHEN`，開機時自動載入。

檢查腳本每一輪做這幾件事：

1. 判斷條件是否成立。電源來源用 `pmset -g ps`；外接螢幕用 `ioreg` 找 `Location` 為 `External` 的 `DCPAVServiceProxy`。
2. 條件成立時 `disablesleep` 設成 1，不成立時設成 0。值跟現在一樣就不動。
3. 用 `ioreg` 讀闔蓋狀態（`AppleClamshellState`）。
4. 條件不成立而且已經闔蓋，下 `pmset sleepnow`。

第 4 步是必要的。闔蓋時把 `disablesleep` 從 1 改回 0，macOS 不會重新判斷闔蓋狀態，所以系統不會自己入睡。這一點可以在 XNU 的 `IOPMrootDomain.cpp` 查到：`kPowerEventUserDisabledSleep` 只更新旗標，不觸發 clamshell 的重新評估。

## 限制

以下的「5 秒」指預設的 `--interval`，改了間隔就跟著變。

- **條件剛成立後 5 秒內就闔蓋，會睡。** 例如插上電源馬上闔蓋：腳本還沒跑到下一輪，`disablesleep` 仍是 0。等幾秒再闔蓋。
- **闔蓋中條件不再成立，最多 5 秒後才睡。** 例如闔蓋中拔電。
- **外接螢幕偵測只支援 Apple Silicon。** Intel Mac 上沒有 `DCPAVServiceProxy`，`display` 條件永遠不成立。
- **UPS 供電視同用電池。** `pmset -g ps` 顯示 `'UPS Power'` 時，`ac` 條件不成立。
- **可能縮短 Power Nap。** 條件不成立而闔蓋入睡後，Power Nap 會讓系統短暫醒來（DarkWake）。如果那時腳本剛好跑到，會直接下 `sleepnow`，背景同步可能被提早結束。
- **闔蓋不睡時散熱較差。** 長時間高負載前，先確認機身溫度可以接受。

## 資源用量

每一輪只跑幾個唯讀命令，CPU 時間約 3 ms。預設每 5 秒一次，一小時合計約 2 秒 CPU。

## 檢查是否正常

```sh
# daemon 有沒有在跑、用的是什麼設定
sudo launchctl print system/local.mac-dont-sleep | grep -E 'state|runs|last exit|MAC_DONT_SLEEP_WHEN|run interval'

# 目前的電源來源與設定
pmset -g ps | head -1
pmset -g | grep SleepDisabled

# 有沒有偵測到外接螢幕（有接的話會多一行 External）
ioreg -r -c DCPAVServiceProxy -d 1 | grep '"Location"'

# 最近的睡眠紀錄
pmset -g log | grep -E "Entering Sleep" | tail -5
```

入睡原因可以從紀錄看出來：

- `Clamshell Sleep`：macOS 原生的闔蓋入睡。
- `Software Sleep pid=...`：腳本下的 `sleepnow`。

## 實測紀錄

2026-11-06 在 macOS 15.5（24F74）、Apple Silicon 上，以 `--when ac --interval 5` 實測：

| 情境 | 紀錄 |
|---|---|
| 插電 → 闔蓋 | 螢幕關閉約 5 分鐘，期間沒有任何 `Entering Sleep` |
| 插電闔蓋 → 拔電 | 螢幕關閉後 5 秒入睡，原因 `Software Sleep` |
| 用電池 → 闔蓋 | 入睡，原因 `Clamshell Sleep` |

`display`、`ac-and-display`、`ac-or-display` 三種條件只用模擬驗過腳本邏輯，還沒接實際的外接螢幕測過。
