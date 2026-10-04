# 为 RunProcess 做贡献

感谢你愿意改进 RunProcess。本文档说明如何报 bug、提需求、提交代码。

---

## 你可以做什么

- **报 bug** —— 开 issue，附上复现步骤
- **提功能建议** —— 开 issue 描述使用场景
- **修 bug** —— 提 Pull Request
- **改文档** —— README、帮助内容、翻译
- **加翻译** —— 欢迎新语言

---

## 开始之前

- 先搜 [已有的 issue](https://github.com/CaoHaoran-Dev/RunProcess/issues)，避免重复
- 大改动先开 issue 讨论方向
- 读一遍 [README](README.md) 了解项目定位

### 不做的事

RunProcess 是**轻量命令启动器**，不是终端模拟器。以下特性有意不支持：

- 交互式 TUI 程序（vim、top、less、ssh 会话）
- 完整终端模拟（ANSI 光标移动、清屏）
- 历史或别名的云同步

需要这些的话，请用专门的终端 App。

### 计划中，尚未实现

这些在路线图上但还没做。写代码前请先开 issue 讨论设计：

- **插件系统** —— 让第三方扩展 RunProcess，加入自定义命令、补全来源或 UI 面板。核心团队做插件 API、加载器和沙箱；具体插件由社区自己维护。
- 命令片段 —— 保存多行脚本，一键执行
- 长输出折叠
- 长命令完成通知

---

## 报 Bug

一个清晰的 bug 报告应包含：

1. **你做了什么** —— 具体命令或 UI 操作
2. **你期望什么** —— 想要的行为
3. **实际发生了什么** —— 真实表现，包括错误信息
4. **环境**：
   - macOS 版本（如 macOS 14.5）
   - RunProcess 版本（关于窗口里看，如 `3.2.0 (1)`）
   - 芯片：Apple Silicon 还是 Intel
   - 会话模式开没开
   - 外观样式

**如果应用崩溃**，附上崩溃日志：

```
~/Library/Logs/DiagnosticReports/
```

找以 `RunProcess-` 开头的文件。

**如果问题跟命令输出有关**，把完整命令贴上。敏感路径自行打码。

---

## 提功能建议

开 issue，加 `enhancement` 标签。描述：

- **问题** —— 现在哪里别扭或缺失
- **你设想的方案** —— 希望怎么工作
- **考虑过的替代方案** —— 还有哪些做法

具体的场景胜过抽象的想法。"我每天跑十次 `docker ps`，想要一个快捷键别名" 比 "加个别名功能" 有用得多。

---

## 开发环境

### 要求

- macOS 12.4 或更高
- Xcode 16.0 或更高
- Swift 5.9+（随 Xcode 附带）

### 克隆与构建

```bash
git clone https://github.com/CaoHaoran-Dev/RunProcess.git
cd RunProcess
open RunProcess.xcodeproj
```

在 Xcode 里：

1. 选择 `RunProcess` scheme
2. 构建（`⌘B`）并运行（`⌘R`）

应用以菜单栏附件的形式启动。找 ⚡ 图标。

### 依赖

用 Swift Package Manager 管理：

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) —— 全局热键
- [Yams](https://github.com/jpsim/Yams) —— 别名和历史的 YAML 解析

Xcode 首次构建时会自动拉取。

### 测试

```bash
xcodebuild test \
  -project RunProcess.xcodeproj \
  -scheme RunProcess \
  -destination "platform=macOS,arch=arm64"
```

CI 对每个 PR 在 `arm64` 和 `x86_64` 上都跑一遍。

---

## 代码风格

### 通用

- 跟随现有风格，不确定时看邻近代码
- 清晰胜过聪明
- 给不明显的地方加注释，显而易见的不用加
- 函数保持小而专注

### Swift 约定

- **缩进**：4 个空格，不用 Tab
- **行长**：目标 120 字符，硬上限 150
- **命名**：类型用 `UpperCamelCase`，成员用 `lowerCamelCase`
- **访问控制**：默认 `private`，需要时才放宽
- **可选值**：避免强解包（`!`），除非不变量明显
- **并发**：跨 actor 使用的数据类型标 `nonisolated`；UI 用 `@MainActor`

### SwiftUI

- 一个文件一个 view（尽量）
- 抽子 view，别把 `body` 嵌太深
- `@State` 给 view 本地状态，`@ObservedObject` 给共享 model
- 内容依赖可选数据时，用 `.sheet(item:)` 而不是 `.sheet(isPresented:)`

### 本地化

**所有面向用户的字符串必须本地化。**

- Swift 里用 `NSLocalizedString("key", comment: "")`
- key 加到三个文件：
  - `RunProcess/Resources/Localizable/en.lproj/Localizable.strings`
  - `RunProcess/Resources/Localizable/zh-Hans.lproj/Localizable.strings`
  - `RunProcess/Resources/Localizable/zh-Hant.lproj/Localizable.strings`
- key 按功能分组（如 `settings.aliases.*`）
- `.strings` 文件保存为 **UTF-8 无 BOM**

漏翻译会以微妙的方式破坏构建。三个文件都要检查。

### 注释

代码里大部分注释是中文，没问题。你习惯哪种语言就用哪种，reviewer 都能看。

---

## Pull Request

### 提交前

- [ ] 项目能无警告构建
- [ ] 本地测试通过
- [ ] 新增的用户可见字符串已在三种语言里本地化
- [ ] 手动测过（冷启动、窗口行为等）
- [ ] 如果改了存储格式，旧数据能无损迁移

### PR 描述

标题清晰，描述包含：

1. **改了什么**
2. **为什么需要**（有 issue 就链接）
3. **怎么测的**
4. **UI 改动配截图**
5. **破坏性变更**，如有

### Commit 消息

祈使句短标题，可选正文：

```
Fix window closing immediately on launch

The didResignActive notification fired before the first window
became key, causing hideAllWindows() to run on a fresh session.
Guard with hasBeenActive flag.

Closes #42
```

避免 `fix stuff` 或 `update`。说清**做了什么**和**为什么**。

### Review 流程

- 维护者几天内 review
- 用新 commit 回应反馈，review 期间不要 force-push
- 通过后维护者 squash 合并

---

## 添加翻译

RunProcess 目前支持：

- 英文（`en`）
- 简体中文（`zh-Hans`）
- 繁体中文（`zh-Hant`）

加新语言：

1. 创建 `RunProcess/Resources/Localizable/<code>.lproj/Localizable.strings`
2. 复制英文版
3. 翻译所有值，key 保持不变
4. 确保文件是 UTF-8 无 BOM
5. 测试：切换系统语言，重启应用

用标准的 [BCP 47](https://en.wikipedia.org/wiki/IETF_language_tag) 代码（如 `ja`、`de`、`fr`）。

---

## 存储格式

RunProcess 把用户数据存在：

```
~/Library/Application Support/RunProcess/
├── aliases.yml      # 命令别名
└── history.yml      # 命令历史（最多 500 条）
```

格式是 YAML。旧的 JSON 文件（`aliases.json`、`history.json`）首次启动会自动迁移。

如果改 schema：

- 版本升级后仍要能读旧数据
- 用真实的旧文件测一遍迁移
- 不要静默丢弃用户数据

---

## 发布流程

仅维护者操作，写在这里是为了透明：

1. 更新 `Info.plist` 里的 `CFBundleShortVersionString` 和 `CFBundleVersion`
2. 功能有变就更新 README
3. 提交：`Release vX.Y.Z`
4. 打标签：`git tag -a vX.Y.Z -m "RunProcess vX.Y.Z"`
5. 推标签：`git push origin vX.Y.Z`
6. 在 GitHub 创建 Release：
   - 标题：`RunProcess vX.Y.Z`
   - 双语说明（英文在前，中文在后）
   - 附上 `RunProcess.zip`
7. 有公证凭据的话，`xcodebuild archive` 后公证

---

## 行为准则

保持礼貌。对代码有异议，不要针对人。默认善意。觉得不对，直接邮件维护者。

禁止骚扰、歧视、人身攻击。违规者封禁。

---

## 问题

- **一般问题**：开 [Discussion](https://github.com/CaoHaoran-Dev/RunProcess/discussions)
- **Bug**：开 [Issue](https://github.com/CaoHaoran-Dev/RunProcess/issues)
- **安全问题**：私信维护者，不要开公开 issue

---

## 许可证

提交贡献即表示同意你的贡献以 [MIT 许可证](LICENSE.md) 授权。

MIT © 2026 CaoHaoran-Dev
