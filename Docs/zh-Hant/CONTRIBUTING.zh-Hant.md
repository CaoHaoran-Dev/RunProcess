# 為 RunProcess 貢獻

> [English](../../CONTRIBUTING.md) · [简体中文](../zh-Hans/CONTRIBUTING.zh-Hans.md) · 繁體中文

感謝你願意改進 RunProcess。本文件說明如何回報 bug、提出需求、提交程式碼。

---

## 你可以做什麼

- **回報 bug** —— 開 issue，附上重現步驟
- **提功能建議** —— 開 issue 描述使用情境
- **修 bug** —— 提 Pull Request
- **改文件** —— README、輔助說明內容、翻譯
- **加翻譯** —— 歡迎新語言

---

## 開始之前

- 先搜 [既有的 issue](https://github.com/CaoHaoran-Dev/RunProcess/issues)，避免重複
- 大改動先開 issue 討論方向
- 讀一遍 [README](../../README.md) 了解專案定位

### 不做的事

RunProcess 是**輕量指令啟動器**，不是終端機模擬器。以下特性有意不支援：

- 前景互動式 TUI 程式（vim、top、less、ssh 工作階段）
- 完整終端機模擬（ANSI 游標移動、清屏）
- 記錄或別名的雲端同步

這些工具的非互動用法是支援的，例如 `echo x | less`、`ssh host 'uname -a'`（帶管線或重導向的指令不會被判為互動式）。需要真正的終端機，請用專門的終端機 App。

### 計劃中，尚未實作

這些在路線圖上但還沒做。寫程式碼前請先開 issue 討論設計：

- **外掛系統** —— 讓第三方擴充 RunProcess，加入自訂指令、補全來源或 UI 面板。核心團隊做外掛 API、載入器和沙箱；具體外掛由社群自己維護。
- 指令片段 —— 儲存多行指令稿，一鍵執行
- 長輸出摺疊
- 長指令完成通知

---

## 回報 Bug

一份清晰的 bug 報告應包含：

1. **你做了什麼** —— 具體指令或 UI 操作
2. **你期望什麼** —— 想要的行為
3. **實際發生了什麼** —— 真實表現，包括錯誤訊息
4. **環境**：
   - macOS 版本（如 macOS 14.5）
   - RunProcess 版本（關於視窗裡看，如 `3.5.0 (1)`）
   - 晶片：Apple Silicon 還是 Intel
   - 工作階段模式開沒開
   - 外觀樣式
   - 設定中選擇的 Shell
   - 是否涉及 Preview/Beta 版

**如果應用程式崩潰**，附上崩潰記錄：

```
~/Library/Logs/DiagnosticReports/
```

找以 `RunProcess-` 開頭的檔案。

**如果問題跟指令輸出有關**，把完整指令貼上。敏感路徑自行打碼。

**如果問題跟遠端功能有關（僅 Preview 版）**，附上 Console.app 裡以 `🌐`、`🔌`、`📨`、`✅`、`⚠️` 開頭的記錄。

---

## 提功能建議

開 issue，加 `enhancement` 標籤。描述：

- **問題** —— 現在哪裡彆扭或缺失
- **你設想的方案** —— 希望怎麼運作
- **考慮過的替代方案** —— 還有哪些做法

具體的情境勝過抽象的想法。「我每天跑十次 `docker ps`，想要一個快捷鍵別名」比「加個別名功能」有用得多。

---

## 開發環境

### 要求

- macOS 14.5 或以上
- Xcode 16.0 或以上
- Swift 5.9+（隨 Xcode 附帶）

> **注意**：CI 使用 `macos-26` 上的 Xcode 26。建置或測試 Preview/Beta 功能可能需要比最低要求更新的 Xcode。如果只改穩定版 target，Xcode 16.0 就夠。

### 複製與建置

```bash
git clone https://github.com/CaoHaoran-Dev/RunProcess.git
cd RunProcess
open RunProcess.xcodeproj
```

在 Xcode 裡：

1. 選擇 `RunProcess` scheme
2. 建置（`⌘B`）並執行（`⌘R`）

應用程式以選單列附件的形式啟動。找 ⚡ 圖示。

要開發 Preview/Beta 功能，選擇 `RunProcess Preview` scheme。它編譯時帶 `BETA` 標記，資料存在 `RunProcess-Beta/`。

### 相依套件

用 Swift Package Manager 管理：

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) —— 全域快速鍵
- [RemoteLinkKit](https://github.com/CaoHaoran-Dev/RemoteLinkKit) —— 遠端連線
- [Sparkle](https://sparkle-project.org) —— 更新分發
- [Yams](https://github.com/jpsim/Yams) —— 別名與記錄的 YAML 解析

Xcode 首次建置時會自動拉取。

### 測試

本專案有兩個測試 Target，各自綁定對應 Scheme。`RemoteConnectionTests` 匯入 `RunProcess_Preview`，只在 Preview Scheme 下編譯。

**正式版 (`RunProcessTests`)：**

```bash
xcodebuild test \
  -project RunProcess.xcodeproj \
  -scheme RunProcess \
  -destination "platform=macOS,arch=arm64" \
  CODE_SIGNING_ALLOWED=NO
```

**預覽/Beta 版 (`RunProcessPreviewTests`)：**

```bash
xcodebuild test \
  -project RunProcess.xcodeproj \
  -scheme "RunProcess Preview" \
  -destination "platform=macOS,arch=arm64" \
  CODE_SIGNING_ALLOWED=NO
```

CI 對每個 PR 在 `arm64` 和 `x86_64` 上都跑一遍。本機沒有簽章憑證時請加 `CODE_SIGNING_ALLOWED=NO`。

只跑單一測試類別，用 `-only-testing`：

```bash
xcodebuild test \
  -project RunProcess.xcodeproj \
  -scheme RunProcess \
  -destination "platform=macOS,arch=arm64" \
  -only-testing:RunProcessTests/ShellQuotingTests \
  CODE_SIGNING_ALLOWED=NO
```

---

## 程式碼風格

### 通用

- 跟隨現有風格，不確定時看鄰近程式碼
- 清晰勝過聰明
- 給不明顯的地方加註解，顯而易見的不用加
- 函式保持小而專注

### Swift 慣例

- **行長**：目標 120 字元，硬上限 150。現有程式碼有超限行——新程式碼請遵守上限，順手整理歡迎但不強制。
- **命名**：型別用 `UpperCamelCase`，成員用 `lowerCamelCase`
- **存取控制**：預設 `private`，需要時才放寬
- **可選值**：避免強制解包（`!`），除非不變量明顯
- **並行**：跨 actor 使用的資料型別標 `nonisolated`；UI 用 `@MainActor`

### SwiftUI

- 一個檔案一個 view（盡量）
- 抽子 view，別把 `body` 嵌太深
- `@State` 給 view 本機狀態，`@ObservedObject` 給共享 model
- 內容依賴可選資料時，用 `.sheet(item:)` 而不是 `.sheet(isPresented:)`

### 在地化

**所有面向使用者的字串必須在地化。**

- Swift 裡用 `NSLocalizedString("key", comment: "")`
- key 加到三個檔案：
  - `RunProcess/Resources/Localizable/en.lproj/Localizable.strings`
  - `RunProcess/Resources/Localizable/zh-Hans.lproj/Localizable.strings`
  - `RunProcess/Resources/Localizable/zh-Hant.lproj/Localizable.strings`
- key 按功能分組（如 `settings.aliases.*`）
- `.strings` 檔案存成 **UTF-8 無 BOM**

缺 key **不會**讓建置失敗——執行時應用程式會直接顯示原始 key 字串。提交前請手動檢查三份檔案。

### 註解

程式碼裡大部分註解是中文，沒問題。你習慣哪種語言就用哪種，reviewer 都能看。

---

## Pull Request

### 提交前

- [ ] 專案能無警告建置
- [ ] 本機測試通過（包含正式版與 Preview 版 Scheme）
- [ ] 新增的使用者可見字串已在三種語言裡在地化
- [ ] 手動測過（冷啟動、視窗行為等）
- [ ] 如果改了儲存格式，舊資料能無損遷移
- [ ] 如果改了遠端協定或存取策略，在 PR 描述裡說明相容性影響

### PR 描述

標題清晰，描述包含：

1. **改了什麼**
2. **為什麼需要**（有 issue 就連結）
3. **怎麼測的**
4. **UI 改動配截圖**
5. **破壞性變更**，如有

### Commit 訊息

祈使句短標題，可選正文：

```
Fix window closing immediately on launch

The didResignActive notification fired before the first window
became key, causing hideAllWindows() to run on a fresh session.
Guard with hasBeenActive flag.

Closes #42
```

避免 `fix stuff` 或 `update`。說清**做了什麼**和**為什麼**。

### Review 流程

- 維護者幾天內 review
- 用新 commit 回應意見，review 期間不要 force-push
- 通過後維護者 squash 合併

---

## 新增翻譯

RunProcess 目前支援：

- 英文（`en`）
- 簡體中文（`zh-Hans`）
- 繁體中文（`zh-Hant`）

加新語言：

1. 建立 `RunProcess/Resources/Localizable/<code>.lproj/Localizable.strings`
2. 複製英文版
3. 翻譯所有值，key 保持不變
4. 確保檔案是 UTF-8 無 BOM
5. 測試：切換系統語言，重新啟動應用程式

用標準的 [BCP 47](https://en.wikipedia.org/wiki/IETF_language_tag) 代碼（如 `ja`、`de`、`fr`）。

---

## 儲存格式

### 正式版

RunProcess 把使用者資料存在：

```
~/Library/Application Support/RunProcess/
├── aliases.yml      # 指令別名
├── history.yml      # 指令記錄（最多 500 筆）
└── paths.yml        # 自訂執行檔搜尋路徑
```

### 預覽/Beta 版

資料存在 `RunProcess-Beta/`，並額外包含：

```
├── workflows.yml         # 多行指令稿
├── remote_hosts.yml      # 已配對的遠端主機
├── paired_clients.yml    # 配對到本機的用戶端
└── remote_access.yml     # 能力開關 + 違禁詞
```

Preview 版的 `UserDefaults` key 帶 `beta.` 前綴（見 `AppSettings.keyPrefix`），兩個版本不共享偏好設定。

格式是 YAML。舊的 JSON 檔案（`aliases.json`、`history.json`）首次啟動會自動遷移。

如果改 schema：

- 版本升級後仍要能讀舊資料
- 用真實的舊檔案測一遍遷移
- 不要靜默丟棄使用者資料
- 新增檔案時同步更新本節

---

## 發佈流程

僅維護者操作，寫在這裡是為了透明：

1. 更新 `Info.plist` 裡的 `CFBundleShortVersionString` 和 `CFBundleVersion`
2. 功能有變就更新 README
3. 提交：`Release vX.Y.Z`
4. 打標籤：`git tag -a vX.Y.Z -m "RunProcess vX.Y.Z"`
5. 推標籤：`git push origin vX.Y.Z`
6. 在 GitHub 建立 Release：
   - 標題：`RunProcess vX.Y.Z`
   - 雙語說明（英文在前，中文在後）
   - 附上 `RunProcess.zip`
7. `xcodebuild archive` 打包。有公證憑證則公證；目前公開版本**未**公證，使用者首次開啟需在系統設定裡點「仍要開啟」（見 README）。

---

## 行為準則

保持禮貌。對程式碼有異議，不要針對人。預設善意。覺得不對，透過儲存庫 profile 上的聯絡方式私下聯絡維護者。

禁止騷擾、歧視、人身攻擊。違規者封鎖。

---

## 問題

- **一般問題**：開 [Discussion](https://github.com/CaoHaoran-Dev/RunProcess/discussions)
- **Bug**：開 [Issue](https://github.com/CaoHaoran-Dev/RunProcess/issues)
- **安全問題**：請透過 [GitHub Security Advisories](https://github.com/CaoHaoran-Dev/RunProcess/security/advisories/new) 私密回報，詳見 [SECURITY.zh-Hant.md](SECURITY.zh-Hant.md)。不要開公開 issue。

---

## 授權條款

提交貢獻即表示同意你的貢獻以 [MIT 授權條款](../../LICENSE.md) 授權。

MIT © 2026 CaoHaoran-Dev
