# RunProcess

> 给 macOS 做的"伪 Windows 运行框" —— 能跑真命令，有玻璃质感，常驻菜单栏

---

## 这是什么

B 站看多了"我修复了 Linux 运行框"的视频，手痒在 macOS 上也搞了一个。

本质就是 `/bin/zsh` 套了个玻璃皮肤，输入什么执行什么。

---

## 功能

- **命令执行** —— 输入命令，执行，实时看输出/报错
- **ANSI 颜色** —— `git status`、`ls -G`、`grep --color` 等的输出会带颜色显示
- **Tab 补全** —— 别名、命令历史、系统命令、文件路径
- **命令历史** —— ↑ / ↓ 按 frecency（频次 × 最近使用）排序浏览
- **历史搜索** —— 按 ⌘R 全量模糊搜索历史命令
- **别名** —— 定义 `gs` → `git status` 之类的短名称，补全里排最前
- **拖拽文件** —— 从 Finder 拖入，自动转义路径
- **Root 执行** —— 勾选后弹密码框，密码仅在当次执行期间存在于内存，不存储不记录
- **默认 Sudo** —— 可把主界面锁定为"始终以 root 执行"
- **全局热键** —— ⌘⌥R 显示/隐藏窗口（可在设置中自定义）
- **菜单栏常驻** —— Dock 不显示
- **三种外观** —— 无、毛玻璃、液态玻璃（macOS 26+）。主界面、设置、帮助、关于、密码框全部跟随
- **浮动窗口** —— 类似 Spotlight
- **多行输入** —— Shift+Enter 换行
- **多窗口** —— 每个窗口独立会话
- **会话模式（可选）** —— 持久 shell，`cd` / `export` 跨命令生效
- **自定义默认工作目录**
- **失去焦点时自动隐藏**
- **应用内帮助** —— 仿 macOS Help Viewer 的侧边栏式帮助窗口
- **本地化** —— 英文、简体中文、繁体中文

---

## 使用

打开应用，菜单栏点 ⚡，输入命令，按回车。

| 输入 | 效果 |
|------|------|
| `ls ~/Downloads` | 列文件 |
| `open .` | Finder 打开当前目录 |
| `git status` | git 状态（带颜色） |
| `/System/Applications/Calculator.app` | 自动加 `open`，启动计算器 |

---

## 快捷键

| 按键 | 作用 |
|------|------|
| `⌘⌥R` | 全局显示/隐藏窗口（可在设置中自定义） |
| `⌘N` | 新建窗口 |
| `⌘R` | 搜索命令历史 |
| `⌘,` | 打开设置 |
| `⌘/` | 打开帮助 |
| `⌘W` | 隐藏窗口 |
| `⌘Q` | 退出 |
| `Enter` | 执行 |
| `Shift+Enter` | 换行 |
| `Tab` | 补全浮窗 |
| `↑` `↓` | 浏览历史命令 |

---

## 外观

在 **设置 → 外观** 中选择：

| 模式 | 说明 | 支持系统 |
|------|------|---------|
| 无 | 系统窗口纯色背景 | macOS 12.4+ |
| 毛玻璃 | `NSVisualEffectView` 模糊 | macOS 12.4+ |
| 液态玻璃 | 原生 Liquid Glass 材质 | macOS 26+ |

macOS 15 及以下默认毛玻璃，macOS 26 及以上默认液态玻璃。不支持的系统上"液态玻璃"选项会被隐藏。

所选样式会应用到主窗口、设置、帮助、关于、sudo 密码框。

---

## 窗口行为

默认情况下，应用失去焦点时所有窗口自动隐藏，行为和 Spotlight 一致。可以在 **设置 → 通用** 中关闭。

---

## 会话模式

在 **设置 → 会话** 中开启。开启后只影响 **新打开的窗口**。

会话模式下，每个窗口持有一个长驻 `zsh` 进程，`cd`、`export` 等命令会在该窗口的后续命令中生效，行为更像真实终端。

会话模式的窗口标题会显示为 `RunProcess - 会话模式 — <当前目录>`。

| 行为 | 非会话模式 | 会话模式 |
|------|-----------|---------|
| `cd` 后下一条命令 | 仍在默认工作目录 | 已切换到新目录 |
| `export` 后下一条命令 | 环境变量丢失 | 环境变量保留 |
| 启动开销 | 每条命令新开 shell | 一次启动，后续复用 |
| 隔离性 | 完全隔离 | 会话内共享状态 |

---

## 命令历史

每条执行过的命令都会记录。历史支撑两个功能：

- **↑ / ↓ 浏览** —— 按 frecency 排序：频次高、最近用过的排前面
- **⌘R 搜索** —— 全量模糊匹配（`gst` 能匹配到 `git status`）

历史存放在：

```
~/Library/Application Support/RunProcess/history.yml
```

最多 500 条，超出时先淘汰最久未用的。

在菜单栏里点 **清除命令历史** 可以清空全部。

---

## 别名

别名让你为常用命令定义短名称，在补全浮窗里排最前。

内置示例：

| 别名 | 展开为 |
|------|--------|
| `gs` | `git status` |
| `gp` | `git pull --rebase` |
| `ll` | `ls -lah` |
| `serve` | `python3 -m http.server 8000` |

自定义别名存放在：

```
~/Library/Application Support/RunProcess/aliases.yml
```

格式：

```yml
[
  { "name": "gs", "expansion": "git status" },
  { "name": "serve", "expansion": "python3 -m http.server 8000" }
]
```

改完重启应用生效。

---

## 默认工作目录

在 **设置 → 工作目录** 中配置。不设置时使用用户主目录。

只影响 **新打开的窗口**。已打开窗口的 shell 已经启动，工作目录不会被强制改变。

如果设置的路径不存在（比如目录被删除），会自动回退到用户主目录，并在设置面板中显示警告。

---

## Sudo

勾选"以 root 执行"后执行命令，会弹出密码框。

**每次执行 sudo 命令都需要重新输入密码。** 密码仅在当次执行期间存在于内存中，不会被存储或记录。

### 默认 Sudo

在 **设置 → Sudo** 中开启 **默认以 root 执行**，主界面的 sudo 开关会锁定为开且不可改，图标变成实心锁。每次执行仍会弹出密码框。

---

## 帮助

按 **⌘/** 或从菜单栏选 **RunProcess 帮助**。帮助窗口左侧是主题列表：

- 概述
- 键盘快捷键
- 命令技巧
- 会话模式
- 以 root 执行
- 别名
- 外观

侧边栏顶部有搜索框，可按标题过滤主题。

---

## 语言

支持英文、简体中文、繁体中文。如果想单独给 RunProcess 换个语言，去 **系统设置 → 通用 → 语言与地区 → 应用程序** 里选。这个功能需要 macOS 13 及以上。

---

## 系统要求

macOS 12.4+，Apple Silicon / Intel 都行

---

## 安装

### 下载（推荐）

从 [Releases](https://github.com/CaoHaoran-Dev/RunProcess/releases) 下载最新的 `RunProcess.zip`

1. 下载解压
2. 把 `RunProcess.app` 拖进 `Applications` 文件夹

> 应用没公证，第一次打开 macOS 会提示不安全，设置里隐私与安全性点仍要打开，不骗你。

### Homebrew

```bash
brew tap CaoHaoran-Dev/apptap
brew trust CaoHaoran-Dev/apptap
brew install runprocess
```

### 从源码编译

```bash
git clone https://github.com/CaoHaoran-Dev/RunProcess.git
cd RunProcess
open RunProcess.xcodeproj
```

需要 Xcode 16.0+。

### 在线体验

访问 GitHub Pages：
[RunProcess WebDemo](https://CaoHaoran-Dev.github.io/RunProcess-WebDemo/)

---

## 技术栈

Swift + SwiftUI，100% AI 生成代码

---

## 文档

- [English README](../../README.md)
- [繁体中文 README](../zh-Hant/README.zh-Hant.md)
- [贡献指南](CONTRIBUTING.zh-Hans.md)
- [License](LICENSE.zh-Hans.md)

---

## 开发故事

AI 写代码，人类提需求，一下午搞定。这就是 2026 年的开发方式。

---

## License

MIT © 2026 CaoHaoran-Dev
