# 安全策略

> [English](../../SECURITY.md) · [简体中文](SECURITY.zh-Hans.md) · [繁體中文](../zh-Hant/SECURITY.zh-Hant.md)

## 支持的版本

安全修复只针对 RunProcess 最新正式版提供。报告前请先确认你用的是最新版本。

## 报告漏洞

请通过 [GitHub Security Advisories](https://github.com/CaoHaoran-Dev/RunProcess/security/advisories/new)
**私密**报告安全漏洞。

**不要为安全问题开公开 issue。** 修复发布前公开披露会让用户处于风险之中。

一份有用的报告应包含：

- 受影响版本（关于窗口里看，如 `3.5.0 (1)`）
- macOS 版本和芯片（Apple Silicon 或 Intel）
- 复现步骤
- 影响范围和可用的 PoC
- 该问题是否已在别处公开

## 后续流程

- 我们会在几天内确认收到报告
- 会同步分诊进展和修复时间线
- 除非你希望匿名，否则会在 advisory 里署名致谢
- 可能需要你补充细节或复现

## 范围

RunProcess 是轻量命令启动器。在范围内：

- 应用本身（命令执行、别名、历史、存储）
- 更新分发（Sparkle）
- `~/Library/Application Support/RunProcess/` 下用户数据的处理

不在范围内：

- 第三方依赖的漏洞（请同时上报上游，也告知我们）
- 需要机器已被攻陷才能触发的问题
- 社会工程学

## 披露

我们遵循协同披露。修复发布后，会发布 GitHub Security Advisory 说明问题和已修复的版本。

## 其他问题

非安全问题请见 [CONTRIBUTING.zh-Hans.md](CONTRIBUTING.zh-Hans.md)。
