# 關於預覽版

> [English](../en/About-Preview-Version.md) · [简体中文](../zh-Hans/About-Preview-Version.zh-Hans.md) · 繁體中文

RunProcess 除了正式版，還提供 **預覽版**。兩版功能集相同，後續變更會先在預覽版落地，因此預覽版可能不穩定。本文說明它和正式版的差異、如何安裝，以及回報問題時要附上什麼。

---

## 和正式版的差別

| | 正式版 | 預覽版 |
| :--- | :--- | :--- |
| 資料目錄 | `~/Library/Application Support/RunProcess/` | `~/Library/Application Support/RunProcess-Beta/` |
| UserDefaults 鍵前綴 | 無 | `beta.` |
| 更新來源 | `appcast.xml` | `appcast-beta.xml` |
| 功能 | — | 與正式版相同，另含進行中的變更 |
| 通訊協定 | 同一版本內穩定 | 不同預覽版之間可能變動 |

預覽版使用獨立的資料目錄和獨立的 UserDefaults 前綴，可以和正式版同時安裝，互不干擾。

---

## 下載

[下載 RunProcess-Preview.zip](https://downloads.caohaoran.dpdns.org/downloads/runprocess/RunProcess-Preview.zip)

也可以前往 [GitHub Releases](https://github.com/CaoHaoran-Dev/RunProcess/releases) 下載歷史版本。

1. 下載解壓縮。
2. 把 `RunProcess Preview.app` 拖進 `Applications` 資料夾。
3. 第一次開啟時如果 macOS 提示不安全，去 **系統設定 → 隱私權與安全性** 點 **仍要開啟**。

---

## 每夜建置

預覽版也會由 [Night Build 工作流](https://github.com/CaoHaoran-Dev/RunProcess/actions/workflows/nightly.yml) 打包：建置 `dev` 分支並上傳 `RunProcess-Preview.YYYY.MM.DD.zip`（日期取北京時間），在最近一次執行的 **Artifacts** 裡下載即可（需登入 GitHub）。

---

## 說明

- 預覽版與正式版來自同一份原始碼，`BETA` 編譯標記只決定資料目錄、UserDefaults 前綴和更新來源。
- 遠端功能要求兩端版本一致，預覽版之間的通訊協定不保證穩定。
- 預覽版寫入的資料不會自動遷移到正式版。
- 預覽版和正式版一樣沒有公證。
- 如果問題只在預覽版出現，請在回報裡附上關於視窗裡的建置號，以及主控台裡以 `🌐`、`🔌`、`📨`、`✅`、`⚠️` 開頭的記錄。
- 使用快捷指令執行遠端指令時，macOS 的沙盒機制可能會限制 `127.0.0.1` 的回環連線。如果遇到連線逾時，請嘗試在主機設定中使用 Mac 的區域網路 IP（如 `192.168.x.x`）代替。
