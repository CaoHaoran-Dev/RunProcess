# 安全性原則

> [English](../../SECURITY.md) · [简体中文](../zh-Hans/SECURITY.zh-Hans.md) · 繁體中文

## 支援的版本

安全性修正只針對 RunProcess 最新正式版提供。回報前請先確認你用的是最新版本。

## 回報漏洞

請透過 [GitHub Security Advisories](https://github.com/CaoHaoran-Dev/RunProcess/security/advisories/new)
**私密**回報安全性漏洞。

**不要為安全性問題開公開 issue。** 修正發佈前公開揭露會讓使用者處於風險之中。

一份有用的回報應包含：

- 受影響版本（關於視窗裡看，如 `3.5.0 (1)`）
- macOS 版本和晶片（Apple Silicon 或 Intel）
- 重現步驟
- 影響範圍和可用的 PoC
- 該問題是否已在別處公開

## 後續流程

- 我們會在幾天內確認收到回報
- 會同步分診進展和修正時間線
- 除非你希望匿名，否則會在 advisory 裡署名致謝
- 可能需要你補充細節或重現

## 範圍

RunProcess 是輕量指令啟動器。在範圍內：

- 應用程式本身（指令執行、別名、記錄、儲存）
- 更新分發（Sparkle）
- `~/Library/Application Support/RunProcess/` 下使用者資料的處理

不在範圍內：

- 第三方相依套件的漏洞（請同時回報上游，也告知我們）
- 需要機器已被攻陷才能觸發的問題
- 社交工程

## 揭露

我們遵循協同揭露。修正發佈後，會發佈 GitHub Security Advisory 說明問題和已修正的版本。

## 其他問題

非安全性問題請見 [CONTRIBUTING.zh-Hant.md](CONTRIBUTING.zh-Hant.md)。
