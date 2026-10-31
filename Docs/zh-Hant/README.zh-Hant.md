# RunProcess

> 一款具備半透明介面與選單列整合的 Spotlight 風格 macOS 指令啟動器。

---

## 總覽

RunProcess 是一款輕量的 macOS 應用程式，提供受 Windows「執行」對話框啟發的快速指令執行介面。它將 `/bin/zsh` 的強大功能與精緻、現代的介面結合，並常駐於選單列中隨時可供存取。

---

## 功能特色

- **指令執行** – 執行任何 shell 指令，並即時顯示輸出
- **ANSI 色彩** – 完整支援 8/16/256 色及 24 位元真彩色。來自 `git status`、`ls -G`、`grep --color` 等工具的輸出將以正確的色彩呈現
- **Tab 補全** – 自動補全別名、指令歷史、系統指令及檔案路徑
- **指令歷史** – 使用 ↑ / ↓ 瀏覽先前的指令，依 frecency（頻率 × 最近使用程度）排序
- **歷史搜尋** – 按下 ⌘H 對整個歷史紀錄進行模糊搜尋
- **別名** – 定義如 `gs` → `git status` 的短名稱；它們會在補全清單中優先顯示
- **自訂路徑** – 新增如 `/Applications` 或 `~/bin` 的資料夾。在這些資料夾中找到的命令列工具可直接透過名稱執行；`.app` 套件也可透過名稱啟動（例如 `Safari`）
- **拖放** – 從 Finder 拖曳檔案，即可自動填入經正確轉義的檔案路徑
- **Root 權限** – 透過安全密碼對話框使用 `sudo` 執行指令。密碼僅在執行期間存於記憶體，絕不儲存或記錄
- **預設 Sudo** – 可選擇將主視窗鎖定為「以 root 身分執行」模式
- **全域快速鍵** – 隨時使用 ⌘⌥R 顯示或隱藏視窗（可在設定中自訂）
- **選單列整合** – 從選單列存取；隱藏 Dock 圖示
- **多種外觀模式** – 無、毛玻璃（Frosted Glass）與液態玻璃（Liquid Glass，macOS 26 及以上）。適用於主視窗、設定、輔助說明、關於及對話框
- **懸浮視窗** – Spotlight 風格的懸浮視窗，具備平滑的寬度動畫
- **多行輸入** – 支援使用 Shift+Enter 輸入多行指令
- **多視窗** – 每個視窗皆為獨立的工作階段
- **工作階段模式（選用）** – 常駐 shell；`cd` 與 `export` 可跨指令持續生效
- **自訂工作目錄** – 為新視窗設定預設工作目錄
- **失焦時自動隱藏** – 應用程式失去焦點時，視窗會自動隱藏
- **內建輔助說明** – 側邊欄式輔助說明視窗，風格仿照 macOS 輔助說明檢視器
- **在地化** – 英文、簡體中文、繁體中文

---

## 使用方式

開啟應用程式，點擊選單列上的 ⚡，輸入指令，然後按下 Enter。

| 輸入 | 結果 |
|-------|--------|
| `ls ~/Downloads` | 列出檔案 |
| `open .` | 在 Finder 中開啟目前目錄 |
| `git status` | 顯示 Git 狀態（帶色彩） |
| `/System/Applications/Calculator.app` | 自動加上 `open` 前綴，啟動計算機 |

---

## 快速鍵

| 按鍵 | 動作 |
|-----|--------|
| `⌘⌥R` | 全域顯示或隱藏視窗（可在設定中自訂） |
| `⌘U` | 檢查更新 |
| `⌘N` | 新增視窗 |
| `⌘H` | 開啟指令歷史 |
| `⌘R` | 重新執行上一條指令 |
| `⌘,` | 開啟設定 |
| `⌘/` | 開啟輔助說明 |
| `⌘W` | 隱藏視窗 |
| `⌘Q` | 結束 |
| `Enter` | 執行 |
| `Shift+Enter` | 換行 |
| `Tab` | 補全彈出視窗 |
| `↑` `↓` | 瀏覽指令歷史 |

---

## 外觀

**設定 → 外觀** 中提供三種外觀模式：

| 模式 | 說明 | 支援情況 |
|------|-------------|--------------|
| 無 | 純色系統視窗背景 | macOS 12.4 及以上 |
| 毛玻璃 | `NSVisualEffectView` 模糊效果 | macOS 12.4 及以上 |
| 液態玻璃 | 原生 Liquid Glass 材質 | macOS 26 及以上 |

在 macOS 15 及更早版本中，預設為毛玻璃；在 macOS 26 及以上版本中，預設為液態玻璃。不支援的系統上會隱藏液態玻璃選項。

所選樣式將套用至主視窗、設定、輔助說明、關於以及 sudo 密碼對話框。

---

## 視窗行為

根據預設，當應用程式失去焦點時，所有視窗會自動隱藏，與 Spotlight 的行為一致。此功能可在 **設定 → 一般** 中停用。

---

## 工作階段模式

在 **設定 → 工作階段** 中啟用。此功能僅影響新開啟的視窗。

在工作階段模式下，每個視窗會維持一個長時間執行的 `zsh` 行程。`cd` 和 `export` 等指令會在同一視窗的後續指令中持續生效，提供更接近真實終端機的行為。

工作階段模式下的視窗標題會顯示為 `RunProcess - 工作階段 — <目前目錄>`。

| 行為 | 非工作階段 | 工作階段 |
|----------|-------------|---------|
| 執行 `cd` 後 | 仍停留在預設工作目錄 | 切換至新目錄 |
| 執行 `export` 後 | 環境變數遺失 | 保留環境變數 |
| 啟動額外開銷 | 每個指令開啟新 shell | 重複使用單一 shell |
| 隔離性 | 完全隔離 | 工作階段內共享狀態 |

---

## 指令歷史

每一條執行過的指令都會被記錄。歷史紀錄支援兩項功能：

- **↑ / ↓ 瀏覽** – 依 frecency 排序：經常使用且最近使用過的指令會排在頂部
- **⌘H 搜尋** – 對整個歷史紀錄進行模糊比對（`gst` 可符合 `git status`）

歷史紀錄儲存於：

```
~/Library/Application Support/RunProcess/history.yml
```

最多保留 500 筆。最舊且最不常使用的紀錄會優先被移除。

可從選單列選擇 **清除指令歷史** 來清除所有歷史紀錄。

---

## 別名

別名可讓您為經常使用的指令定義短名稱。它們在補全彈出視窗中的優先順序最高。

內建範例：

| 別名 | 展開為 |
|-------|-----------|
| `gs` | `git status` |
| `gp` | `git pull --rebase` |
| `ll` | `ls -lah` |
| `serve` | `python3 -m http.server 8000` |

自訂別名儲存於：

```
~/Library/Application Support/RunProcess/aliases.yml
```

格式：

```yml
aliases:
  - name: gs
    expansion: git status
  - name: serve
    expansion: python3 -m http.server 8000
```

編輯後請重新啟動應用程式。

---

## 路徑

**設定 → 路徑** 包含兩個區塊。

### 預設工作目錄

為新視窗設定工作目錄。若未設定，將使用使用者的主目錄。僅影響新開啟的視窗。

若設定的路徑已不存在，應用程式將退回主目錄，並在設定中顯示警告。

### 自訂路徑

新增包含命令列工具與 `.app` 套件的資料夾，使其可透過名稱執行。

| 輸入 | 執行 |
|-------|------|
| `myscript`（位於此處新增的 `~/bin` 中） | `~/bin/myscript` |
| `fastfetch`（透過 Homebrew 安裝） | `/opt/homebrew/bin/fastfetch` |
| `Safari`（於此處新增 `/Applications`） | `/Applications/Safari.app` |
| `Keynote`（同上） | `/Applications/Keynote.app` |

此處的資料夾會**附加至 PATH 尾端**，因此系統 PATH 與您在 `~/.zshrc` 中設定的任何 PATH 都會被保留。命令列工具由 `zsh` 本身解析。`.app` 套件會以不區分大小寫的方式進行比對，並透過 `open -b <bundleId>` 啟動，因此輸入 `keynote` 即可開啟 `Keynote.app`。

自訂路徑儲存於：

```
~/Library/Application Support/RunProcess/paths.yml
```

格式：

```yml
paths:
  - /Applications
  - ~/bin
  - /opt/homebrew/bin
```

變更將立即生效。

### 自訂路徑

新增資料夾，其中的命令列工具與 `.app` 可直接用名稱執行。

| 輸入 | 執行 |
|------|------|
| `myscript`（在 `~/bin`，已加入這裡） | `~/bin/myscript` |
| `fastfetch`（Homebrew 安裝） | `/opt/homebrew/bin/fastfetch` |
| `Safari`（`/Applications` 已加入這裡） | `/Applications/Safari.app` |
| `Keynote`（同上） | `/Applications/Keynote.app` |

這裡的資料夾會被**追加到 PATH**，所以系統 PATH 和你 `~/.zshrc` 裡設定的 PATH 都會保留。命令列工具由 `zsh` 自己按 PATH 查找。`.app` 會大小寫不敏感比對，並透過 `open -b <bundleId>` 啟動，所以輸入 `keynote` 能開啟 `Keynote.app`。

自訂路徑存放於：

```
~/Library/Application Support/RunProcess/paths.yml
```

格式：

```yml
paths:
  - /Applications
  - ~/bin
  - /opt/homebrew/bin
```

修改後立即生效。

---

## Sudo

在執行指令前啟用「以 root 身分執行」，將會跳出密碼提示。

每次執行 sudo 指令時都需要重新輸入密碼。密碼僅在執行期間存於記憶體，絕不儲存或記錄。

### 預設 Sudo

在 **設定 → Sudo** 中啟用 **永遠以 root 身分執行**，可將主視窗的 sudo 開關鎖定在開啟狀態。該開關將變為唯讀，並標示實心鎖頭圖示。每次執行指令時仍會提示輸入密碼。

---

## 更新

RunProcess 使用 [Sparkle](https://sparkle-project.org) 提供更新。

- **檢查更新** – 可於選單列使用（⌘U）
- **自動檢查** – 於設定 → 更新中切換。每天在背景下檢查一次
- **自動下載** – 於設定 → 更新中切換。安裝仍需確認

更新套件在安裝前會經過密碼學簽章與驗證。

---

## 更新

RunProcess 使用 [Sparkle](https://sparkle-project.org) 分發更新。

- **檢查更新** —— 在選單列裡（⌘U）
- **自動檢查** —— 設定 → 更新 裡的開關。每天在背景自動檢查一次
- **自動下載** —— 設定 → 更新 裡的開關。安裝仍需確認

更新套件經過加密簽章，安裝前會驗證。

---

## 輔助說明

按下 **⌘/** 或從選單列選擇 **RunProcess 輔助說明**。輔助說明視窗左側包含主題側邊欄：

- 總覽
- 鍵盤快速鍵
- 指令技巧
- 工作階段模式
- 以 root 身分執行
- 別名
- 外觀

側邊欄包含搜尋欄位，可依標題篩選主題。

---

## 語言

RunProcess 支援英文、簡體中文與繁體中文。若要僅針對 RunProcess 使用不同語言，請前往 **系統設定 → 一般 → 語言與地區 → 應用程式** 並選擇 RunProcess。此功能需要 macOS 13 或以上版本。

---

## 系統需求

- macOS 12.4 或以上版本
- Apple Silicon 或 Intel 處理器

---

## 安裝

### 下載（建議）

從 [Releases](https://github.com/CaoHaoran-Dev/RunProcess/releases) 下載最新的 `RunProcess.zip`。

1. 下載並解壓縮檔案。
2. 將 `RunProcess.app` 移至您的 `Applications` 資料夾。

> 此應用程式未經過公證，因此 macOS 在首次啟動時可能會顯示安全性警告。請前往 **系統設定 → 隱私權與安全性** 並點擊 **仍要開啟**。

### Homebrew

```bash
brew tap CaoHaoran-Dev/apptap
brew trust CaoHaoran-Dev/apptap
brew install runprocess
```

### 從原始碼建置

```bash
git clone https://github.com/CaoHaoran-Dev/RunProcess.git
cd RunProcess
open RunProcess.xcodeproj
```

需要 Xcode 16.0 或以上版本。

### 線上體驗

造訪 GitHub Pages 展示：
[Process WebHub](https://CaoHaoran-Dev.github.io/Process-WebHub/runprocess)

---

## 設定檔

RunProcess 將使用者資料儲存於：

```
~/Library/Application Support/RunProcess/
├── aliases.yml      # 指令別名
├── history.yml      # 指令歷史（最多 500 筆）
└── paths.yml        # 自訂執行檔搜尋路徑
```

### aliases.yml

格式：

```yml
aliases:
  - name: gs
    expansion: git status
  - name: serve
    expansion: python3 -m http.server 8000
```

### history.yml

自動管理。最多 500 筆。

### paths.yml

格式：

```yml
paths:
  - /Applications
  - ~/bin
  - /opt/homebrew/bin
```

### 移轉

較舊的 JSON 檔案（`aliases.json`、`history.json`）將在首次啟動時自動移轉。

---

## 技術堆疊

Swift 與 SwiftUI

---

## 文件

- [簡體中文 README](../zh-Hans/README.zh-Hans.md)
- [English README](../../README.md)
- [貢獻指南](CONTRIBUTING.zh-Hant.md)
- [授權條款](LICENSE.md)

---

## 授權條款

MIT © 2026 CaoHaoran-Dev
