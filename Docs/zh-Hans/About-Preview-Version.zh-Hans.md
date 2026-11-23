# 关于预览版

> [English](../en/About-Preview-Version.md) · 简体中文 · [繁體中文](../zh-Hant/About-Preview-Version.zh-Hant.md)

RunProcess 除了正式版，还提供 **预览版**。两版功能集相同，后续变更会先在预览版落地，因此预览版可能不稳定。本文说明它和正式版的差异、如何安装，以及反馈问题时要附上什么。

---

## 和正式版的区别

| | 正式版 | 预览版 |
| :--- | :--- | :--- |
| 数据目录 | `~/Library/Application Support/RunProcess/` | `~/Library/Application Support/RunProcess-Beta/` |
| UserDefaults 键前缀 | 无 | `beta.` |
| 更新源 | `appcast.xml` | `appcast-beta.xml` |
| 功能 | — | 与正式版相同，另含进行中的改动 |
| 通信协议 | 同一版本内稳定 | 不同预览版之间可能变化 |

预览版使用独立的数据目录和独立的 UserDefaults 前缀，可以和正式版同时安装，互不干扰。

---

## 下载

[下载 RunProcess-Preview.zip](https://downloads.caohaoran.dpdns.org/downloads/runprocess/RunProcess-Preview.zip)

也可以前往 [GitHub Releases](https://github.com/CaoHaoran-Dev/RunProcess/releases) 下载历史版本。

1. 下载解压。
2. 把 `RunProcess Preview.app` 拖进 `Applications` 文件夹。
3. 第一次打开时如果 macOS 提示不安全，去 **系统设置 → 隐私与安全性** 点 **仍要打开**。

---

## 每夜构建

预览版还会由 [Night Build 工作流](https://github.com/CaoHaoran-Dev/RunProcess/actions/workflows/nightly.yml) 打包：构建 `dev` 分支并上传 `RunProcess-Preview.YYYY.MM.DD.zip`（日期取北京时间），在最近一次运行的 **Artifacts** 里下载即可（需要登录 GitHub）。

---

## 说明

- 预览版与正式版来自同一份源码，`BETA` 编译标记只决定数据目录、UserDefaults 前缀和更新源。
- 远程功能要求两端版本一致，预览版之间的通信协议不保证稳定。
- 预览版写入的数据不会自动迁移到正式版。
- 预览版和正式版一样没有公证。
- 如果问题只在预览版出现，请在报告里附上关于窗口里的构建号，以及控制台里以 `🌐`、`🔌`、`📨`、`✅`、`⚠️` 开头的日志。
- 使用快捷指令执行远程命令时，macOS 的沙盒机制可能会限制 `127.0.0.1` 的回环连接。如果遇到连接超时，请尝试在主机设置中使用 Mac 的局域网 IP（如 `192.168.x.x`）代替。
