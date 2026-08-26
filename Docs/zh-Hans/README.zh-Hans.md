# RunProcess

> 给 macOS 做的"伪 Windows 运行框" —— 能跑真命令，有毛玻璃，常驻菜单栏

---

## 这是什么

B 站看多了"我修复了 Linux 运行框"的视频，手痒在 macOS 上也搞了一个。

本质就是 `/bin/zsh` 套了个毛玻璃皮肤，输入什么执行什么。

---

## 功能

- 输入命令，执行，看输出/报错
- Tab 补全（系统命令 + 历史命令 + 路径）
- 拖拽文件自动填充路径
- 勾选"以 root 执行"弹密码框（密码安全传递，不泄露）
- 菜单栏常驻，Dock 不显示
- 毛玻璃，自动适配深色/浅色
- 浮动窗口，类似 Spotlight
- 全局热键 ⌘⌥R 显示/隐藏
- 支持多行输入（Shift+Enter 换行）
- 输入 `.app` 路径自动加 `open`

---

## 使用

打开应用，菜单栏点 ⚡，输入命令，按回车。

| 输入 | 效果 |
|------|------|
| `ls ~/Downloads` | 列文件 |
| `open .` | Finder 打开当前目录 |
| `git status` | git 状态 |
| `/Applications/Calculator.app` | 自动加 `open`，启动计算器 |

---

## 快捷键

| 按键 | 作用 |
|------|------|
| `⌘⌥R` | 全局显示/隐藏窗口 |
| `Enter` | 执行 |
| `Shift+Enter` | 换行 |
| `Tab` | 补全浮窗 |
| `↑↓` | 历史命令导航 |
| `⌘W` | 隐藏窗口 |
| `⌘Q` | 退出 |

---

## 系统要求

macOS 12.4+，Apple Silicon / Intel 都行

---

## 安装

### 下载（推荐）

从 [Releases](https://github.com/CaoHaoran-Dev/RunProcess/releases) 下载最新的 `RunProcess.zip`

1. 下载解压
2. 把 `RunProcess.app` 拖进 `Applications` 文件夹
3. 右键点击应用 → **打开** → 确认

> 应用没公证，第一次打开 macOS 会提示不安全，右键打开就行了，不骗你。

### 从源码编译

```bash
git clone https://github.com/CaoHaoran-Dev/RunProcess.git
cd RunProcess
open RunProcess.xcodeproj
```

需要 Xcode 16.0+。

### 在线体验

访问 GitHub Pages：
[https://CaoHaoran-Dev.github.io/RunProcess-WebDemo/](https://CaoHaoran-Dev.github.io/RunProcess-WebDemo/index.html)

---

## 技术栈

Swift + SwiftUI，100% AI 生成代码

---

## 文档

- [English README](../../README.md)
- [License](LICENSE.zh-Hans.md)

---

## 开发故事

AI 写代码，人类提需求，一下午搞定。这就是 2026 年的开发方式。

---

## License

MIT © CaoHaoran-Dev
