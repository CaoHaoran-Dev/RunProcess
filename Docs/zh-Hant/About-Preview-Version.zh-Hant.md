# 關於預覽版

> [English](../en/About-Preview-Version.md) · [简体中文](../zh-Hans/About-Preview-Version.zh-Hans.md) · 繁體中文

RunProcess 除了正式版，還提供 **預覽版**。預覽版包含仍在測試中的功能，可能隨時變動或移除。本文說明它和正式版的差異、如何安裝，以及回報問題時要附上什麼。

---

## 和正式版的差別

| | 正式版 | 預覽版 |
| :--- | :--- | :--- |
| 資料目錄 | `~/Library/Application Support/RunProcess/` | `~/Library/Application Support/RunProcess-Beta/` |
| 更新來源 | `appcast.xml` | `appcast-beta.xml` |
| 遠端連線 | — | 配對、Bonjour 探索、遠端執行 |
| 工作流 | — | 用短名稱觸發的多行指令碼 |
| 遠端權限 | — | 依能力開關 + 違禁詞 |
| 配對通知 | — | 帶 6 位驗證碼的系統通知 |

預覽版使用獨立的資料目錄和獨立的 UserDefaults 前綴，可以和正式版同時安裝，互不干擾。

---

## 下載

[下載 RunProcess-Preview.zip](https://downloads.caohaoran.dpdns.org/downloads/runprocess/RunProcess-Preview.zip)

也可以前往 [GitHub Releases](https://github.com/CaoHaoran-Dev/RunProcess/releases) 下載歷史版本。

1. 下載解壓縮。
2. 把 `RunProcess Preview.app` 拖進 `Applications` 資料夾。
3. 第一次開啟時如果 macOS 提示不安全，去 **系統設定 → 隱私權與安全性** 點 **仍要開啟**。

---

## 說明

- 預覽版功能由 `BETA` 編譯標記控制，正式版裡不存在這些功能。
- 遠端功能要求兩端版本一致，預覽版之間的通訊協定不保證穩定。
- 預覽版寫入的資料不會自動遷移到正式版。
- 預覽版和正式版一樣沒有公證。
- 如果問題只在預覽版出現，請在回報裡附上關於視窗裡的建置號，以及主控台裡以 `🌐`、`🔌`、`📨`、`✅`、`⚠️` 開頭的記錄。
