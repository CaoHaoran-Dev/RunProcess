# RunProcess

> 給 macOS 做的「偽 Windows 執行框」—— 能跑真指令，有玻璃質感，常駐選單列

---

## 這是什麼

B 站看多了「我修復了 Linux 執行框」的影片，手癢在 macOS 上也搞了一個。

本質就是 `/bin/zsh` 套了個玻璃面板，輸入什麼執行什麼。

---

## 功能

- **指令執行** —— 輸入指令，執行，即時看輸出/錯誤
- **ANSI 顏色** —— `git status`、`ls -G`、`grep --color` 等的輸出會帶顏色顯示
- **Tab 補全** —— 別名、指令記錄、系統指令、檔案路徑
- **指令記錄** —— ↑ / ↓ 依 frecency（頻次 × 最近使用）排序瀏覽
- **記錄搜尋** —— 按 ⌘R 全文模糊搜尋歷史指令
- **別名** —— 定義 `gs` → `git status` 之類的短名稱，補全裡排最前
- **拖放檔案** —— 從 Finder 拖入，自動轉義路徑
- **Root 執行** —— 勾選後彈密碼框，密碼僅在當次執行期間存在於記憶體，不儲存不記錄
- **預設 Sudo** —— 可把主視窗鎖定為「一律以 root 執行」
- **全域快速鍵** —— ⌘⌥R 顯示/隱藏視窗（可在設定中自訂）
- **選單列常駐** —— Dock 不顯示
- **三種外觀** —— 無、毛玻璃、液態玻璃（macOS 26+）。主視窗、設定、輔助說明、關於、密碼框全部跟隨
- **浮動視窗** —— 類似 Spotlight
- **多行輸入** —— Shift+Enter 換行
- **多視窗** —— 每個視窗獨立工作階段
- **工作階段模式（選用）** —— 長駐 shell，`cd` / `export` 跨指令生效
- **自訂預設工作目錄**
- **失去焦點時自動隱藏**
- **應用程式內輔助說明** —— 仿 macOS Help Viewer 的側邊欄式輔助說明視窗
- **在地化** —— 英文、簡體中文、繁體中文

---

## 使用

開啟應用程式，選單列點 ⚡，輸入指令，按 Enter。

| 輸入 | 效果 |
|------|------|
| `ls ~/Downloads` | 列出檔案 |
| `open .` | Finder 開啟目前目錄 |
| `git status` | git 狀態（帶顏色） |
| `/System/Applications/Calculator.app` | 自動加上 `open`，啟動計算機 |

---

## 快速鍵

| 按鍵 | 作用 |
|------|------|
| `⌘⌥R` | 全域顯示/隱藏視窗（可在設定中自訂） |
| `⌘N` | 新增視窗 |
| `⌘R` | 搜尋指令記錄 |
| `⌘,` | 開啟設定 |
| `⌘/` | 開啟輔助說明 |
| `⌘W` | 隱藏視窗 |
| `⌘Q` | 結束 |
| `Enter` | 執行 |
| `Shift+Enter` | 換行 |
| `Tab` | 補全浮窗 |
| `↑` `↓` | 瀏覽歷史指令 |

---

## 外觀

在 **設定 → 外觀** 中選擇：

| 模式 | 說明 | 支援系統 |
|------|------|---------|
| 無 | 系統視窗純色背景 | macOS 12.4+ |
| 毛玻璃 | `NSVisualEffectView` 模糊 | macOS 12.4+ |
| 液態玻璃 | 原生 Liquid Glass 材質 | macOS 26+ |

macOS 15 及以下預設毛玻璃，macOS 26 及以上預設液態玻璃。不支援的系統上「液態玻璃」選項會被隱藏。

所選樣式會套用到主視窗、設定、輔助說明、關於、sudo 密碼框。

---

## 視窗行為

預設情況下，應用程式失去焦點時所有視窗自動隱藏，行為和 Spotlight 一致。可以在 **設定 → 一般** 中關閉。

---

## 工作階段模式

在 **設定 → 工作階段** 中開啟。開啟後只影響 **新開啟的視窗**。

工作階段模式下，每個視窗持有一個長駐 `zsh` 行程，`cd`、`export` 等指令會在該視窗的後續指令中生效，行為更像真實終端機。

工作階段模式的視窗標題會顯示為 `RunProcess - 工作階段模式 — <目前目錄>`。

| 行為 | 非工作階段模式 | 工作階段模式 |
|------|-----------|---------|
| `cd` 後下一條指令 | 仍在預設工作目錄 | 已切換到新目錄 |
| `export` 後下一條指令 | 環境變數遺失 | 環境變數保留 |
| 啟動開銷 | 每條指令新開 shell | 一次啟動，後續重用 |
| 隔離性 | 完全隔離 | 工作階段內共享狀態 |

---

## 指令記錄

每條執行過的指令都會記錄。記錄支撐兩個功能：

- **↑ / ↓ 瀏覽** —— 依 frecency 排序：頻次高、最近用過的排前面
- **⌘R 搜尋** —— 全文模糊比對（`gst` 能比對到 `git status`）

記錄存放在：

```
~/Library/Application Support/RunProcess/history.json
```

最多 500 條，超出時先淘汰最久未用的。

在選單列裡點 **清除指令記錄** 可以清空全部。

---

## 別名

別名讓你為常用指令定義短名稱，在補全浮窗裡排最前。

內建範例：

| 別名 | 展開為 |
|------|--------|
| `gs` | `git status` |
| `gp` | `git pull --rebase` |
| `ll` | `ls -lah` |
| `serve` | `python3 -m http.server 8000` |

自訂別名存放在：

```
~/Library/Application Support/RunProcess/aliases.json
```

格式：

```json
[
  { "name": "gs", "expansion": "git status" },
  { "name": "serve", "expansion": "python3 -m http.server 8000" }
]
```

改完重新啟動應用程式生效。

---

## 預設工作目錄

在 **設定 → 工作目錄** 中設定。不設定時使用使用者主目錄。

只影響 **新開啟的視窗**。已開啟視窗的 shell 已經啟動，工作目錄不會被強制改變。

如果設定的路徑不存在（例如目錄被刪除），會自動回退到使用者主目錄，並在設定面板中顯示警告。

---

## Sudo

勾選「以 root 執行」後執行指令，會彈出密碼框。

**每次執行 sudo 指令都需要重新輸入密碼。** 密碼僅在當次執行期間存在於記憶體中，不會被儲存或記錄。

### 預設 Sudo

在 **設定 → Sudo** 中開啟 **預設以 root 執行**，主視窗的 sudo 開關會鎖定為開且不可改，圖示變成實心鎖。每次執行仍會彈出密碼框。

---

## 輔助說明

按 **⌘/** 或從選單列選 **RunProcess 輔助說明**。輔助說明視窗左側是主題列表：

- 總覽
- 鍵盤快速鍵
- 指令技巧
- 工作階段模式
- 以 root 執行
- 別名
- 外觀

側邊欄頂端有搜尋框，可依標題過濾主題。

---

## 語言

支援英文、簡體中文、繁體中文。如果想單獨給 RunProcess 換個語言，去 **系統設定 → 一般 → 語言與地區 → 應用程式** 裡選。這個功能需要 macOS 13 及以上。

---

## 系統需求

macOS 12.4+，Apple Silicon / Intel 都行

---

## 安裝

### 下載（推薦）

從 [Releases](https://github.com/CaoHaoran-Dev/RunProcess/releases) 下載最新的 `RunProcess.zip`

1. 下載解壓
2. 把 `RunProcess.app` 拖進 `Applications` 資料夾

> 應用程式沒公證，第一次開啟 macOS 會提示不安全，設定裡隱私與安全性點仍要打開，不騙你。

### Homebrew

```bash
brew tap CaoHaoran-Dev/apptap
brew trust CaoHaoran-Dev/apptap
brew install runprocess
```

### 從原始碼編譯

```bash
git clone https://github.com/CaoHaoran-Dev/RunProcess.git
cd RunProcess
open RunProcess.xcodeproj
```

需要 Xcode 16.0+。

### 線上體驗

前往 GitHub Pages：
[RunProcess WebDemo](https://CaoHaoran-Dev.github.io/RunProcess-WebDemo/)

---

## 技術棧

Swift + SwiftUI，100% AI 生成程式碼

---

## 文件

- [English README](../../README.md)
- [简体中文 README](../zh-Hans/README.zh-Hans.md)
- [License](LICENSE.zh-Hans.md)

---

## 開發故事

AI 寫程式，人類提需求，一個下午搞定。這就是 2026 年的開發方式。

---

## License

MIT © 2026 CaoHaoran-Dev

