# 关于预览版

> [English](../en/About-Preview-Version.md) · 简体中文 · [繁體中文](../zh-Hant/About-Preview-Version.zh-Hant.md)

RunProcess 除了正式版，还提供 **预览版**。预览版包含仍在测试中的功能，可能随时改动或移除。本文说明它和正式版的差异、如何安装，以及反馈问题时要附上什么。

---

## 和正式版的区别

| | 正式版 | 预览版 |
| :--- | :--- | :--- |
| 数据目录 | `~/Library/Application Support/RunProcess/` | `~/Library/Application Support/RunProcess-Beta/` |
| 更新源 | `appcast.xml` | `appcast-beta.xml` |
| 远程连接 | — | 配对、Bonjour 发现、远程执行 |
| 工作流 | — | 用短名称触发的多行脚本 |
| 远程权限 | — | 按能力开关 + 违禁词 |
| 配对通知 | — | 带 6 位验证码的系统通知 |

预览版使用独立的数据目录和独立的 UserDefaults 前缀，可以和正式版同时安装，互不干扰。

---

## 下载

[下载 RunProcess-Preview.zip](https://downloads.caohaoran.dpdns.org/downloads/runprocess/RunProcess-Preview.zip)

也可以前往 [GitHub Releases](https://github.com/CaoHaoran-Dev/RunProcess/releases) 下载历史版本。

1. 下载解压。
2. 把 `RunProcess Preview.app` 拖进 `Applications` 文件夹。
3. 第一次打开时如果 macOS 提示不安全，去 **系统设置 → 隐私与安全性** 点 **仍要打开**。

---

## 说明

- 预览版功能由 `BETA` 编译标记控制，正式版里不存在这些功能。
- 远程功能要求两端版本一致，预览版之间的通信协议不保证稳定。
- 预览版写入的数据不会自动迁移到正式版。
- 预览版和正式版一样没有公证。
- 如果问题只在预览版出现，请在报告里附上关于窗口里的构建号，以及控制台里以 `🌐`、`🔌`、`📨`、`✅`、`⚠️` 开头的日志。
