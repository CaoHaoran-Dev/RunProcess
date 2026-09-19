# RunProcess

> 為 macOS 打造的「仿 Windows 執行方塊」——可執行真實命令，具備玻璃質感，常駐選單列。

---

## 簡介

RunProcess 是一款輕量的 macOS 應用程式，提供類似 Windows「執行」對話框的快速命令執行介面。它將 `/bin/zsh` 的能力與現代化的視覺介面結合，並常駐於選單列，隨時可用。

---

## 功能

- **命令執行**：執行任意 shell 命令，即時顯示輸出
- **Tab 補全**：自動補全系統命令、歷史命令與檔案路徑
- **命令歷史**：使用 ↑ 與 ↓ 方向鍵瀏覽先前命令
- **拖放支援**：從 Finder 拖曳檔案，自動填入正確轉義的檔案路徑
- **Root 權限**：透過安全的密碼對話框以 `sudo` 執行命令。密碼僅於執行期間存在於記憶體中，不會被儲存或記錄
- **全域快速鍵**：隨時以 ⌘⌥R 顯示或隱藏視窗（可於設定中自訂）
- **選單列整合**：可從選單列存取；Dock 圖示不會顯示
- **多種外觀模式**：可選擇「無」、「毛玻璃」與「液態玻璃」（macOS 26 及以上）
- **浮動視窗**：類似 Spotlight 的浮動視窗
- **多行輸入**：支援以 Shift+Enter 輸入多行命令
- **多重視窗**：每個視窗皆為獨立的工作階段
- **工作階段模式（選用）**：持久 shell，`cd` 與 `export` 可跨命令保留
- **自訂工作目錄**：可設定新視窗的預設工作目錄
- **失去焦點時自動隱藏**：應用程式失去焦點時，視窗會自動隱藏

---

## 使用方式

開啟應用程式，點選選單列中的 ⚡，輸入命令，然後按下 Enter。

| 輸入 | 結果 |
|------|------|
| `ls ~/Downloads` | 列出檔案 |
| `open .` | 在 Finder 中開啟目前目錄 |
| `git status` | 顯示 Git 狀態 |
| `/System/Applications/Calculator.app` | 自動加上 `open` 前置詞，啟動計算機 |

---

## 快速鍵

| 按鍵 | 動作 |
|------|------|
| `⌘⌥R` | 全域顯示或隱藏視窗（可於設定中自訂） |
| `⌘N` | 新增視窗 |
| `Enter` | 執行 |
| `Shift+Enter` | 換行 |
| `Tab` | 補全彈出視窗 |
| `↑` `↓` | 命令歷史瀏覽 |
| `⌘W` | 隱藏視窗 |
| `⌘Q` | 結束 |

---

## 外觀

於 **設定 → 外觀** 中選擇：

| 模式 | 說明 | 支援系統 |
|------|------|---------|
| 無 | 系統視窗純色背景 | macOS 12.4 及以上 |
| 毛玻璃 | `NSVisualEffectView` 模糊效果 | macOS 12.4 及以上 |
| 液態玻璃 | 原生 Liquid Glass 材質 | macOS 26 及以上 |

macOS 15 及以下預設為毛玻璃，macOS 26 及以上預設為液態玻璃。不支援的系統上，「液態玻璃」選項會被隱藏。

---

## 視窗行為

預設情況下，應用程式失去焦點時所有視窗會自動隱藏，行為與 Spotlight 一致。可於 **設定 → 視窗** 中關閉此行為。

---

## 工作階段模式

於 **設定 → 工作階段** 中啟用。此設定僅影響 **新開啟的視窗**。

在工作階段模式下，每個視窗會維持一個長駐的 `zsh` 程序。`cd`、`export` 等命令會在該視窗的後續命令中持續生效，行為更接近真實終端機。

工作階段模式的視窗標題會顯示為 `RunProcess - 工作階段模式 — <目前目錄>`。

| 行為 | 非工作階段模式 | 工作階段模式 |
|------|---------------|-------------|
| 執行 `cd` 後的下一條命令 | 仍位於預設工作目錄 | 已切換至新目錄 |
| 執行 `export` 後的下一條命令 | 環境變數遺失 | 環境變數保留 |
| 啟動開銷 | 每條命令皆啟動新的 shell | 啟動一次後重複使用 |
| 隔離性 | 完全隔離 | 工作階段內共用狀態 |

---

## 工作目錄

於 **設定 → 工作目錄** 中設定。若未設定，將使用使用者的個人專屬目錄。

此設定僅影響 **新開啟的視窗**。已開啟的視窗會保留其既有 shell 的工作目錄。

若設定的路徑已不存在，應用程式會退回至個人專屬目錄，並於設定中顯示警告。

---

## Sudo

在執行命令前勾選「以 root 執行」，即會顯示密碼輸入對話框。

**每次執行 sudo 命令皆需重新輸入密碼。** 密碼僅於執行期間存在於記憶體中，不會被儲存或記錄。

---

## 語言

RunProcess 支援英文、簡體中文與繁體中文。若僅想為 RunProcess 設定不同的語言，請前往 **系統設定 → 一般 → 語言與地區 → 應用程式**，並選擇 RunProcess。此功能需要 macOS 13 及以上。

---

## 系統需求

- macOS 12.4 及以上
- Apple Silicon 或 Intel

---

## 安裝

### 下載（建議方式）

從 [Releases](https://github.com/CaoHaoran-Dev/RunProcess/releases) 下載最新的 `RunProcess.zip`。

1. 下載並解壓縮檔案。
2. 將 `RunProcess.app` 移至 `Applications` 檔案夾。

> 應用程式未經公證，因此 macOS 可能會在首次啟動時顯示安全性警告。請前往 **系統設定 > 隱私權與安全性**，然後按一下 **仍要打開**。

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

需要 Xcode 16.0 及以上。

### 線上體驗

前往 GitHub Pages 展示頁面：
[RunProcess WebDemo](https://CaoHaoran-Dev.github.io/RunProcess-WebDemo/)

---

## 技術架構

Swift 與 SwiftUI

---

## 文件

- [English README](../../README.md)
- [简体 README](../zh-Hans/README.zh-Hans.md)
- [License](../../LICENSE.md)

---

## 授權條款

MIT © 2026 CaoHaoran-Dev
