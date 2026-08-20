# RunProcess

macOS 上的“伪 Windows 运行框” —— 带毛玻璃效果，能跑真命令。

> 当前版本：1.0.0 · 能用

## 这是什么

B 站上老看到“我修复了 Linux 运行框”的视频，看多了就手痒，在 macOS 上也搞了一个。

本质就是 `/bin/zsh` 套了个毛玻璃皮肤，输入什么执行什么，输出和报错都能看见。

## 功能

- 输入命令，执行命令，显示结果
- 毛玻璃效果
- 支持 "open" 调用 GUI 应用
- 支持拖入文件自动填充路径

## 技术栈

- Swift + SwiftUI
- Process + Pipe 调用 `/bin/zsh`
- 100% AI 生成代码
- macOS 12.4+

## 使用

打开应用，输入命令，按回车。

| 输入 | 效果 |
|------|------|
| `echo "Hi"` | 显示 Hi |
| `ls ~/Downloads` | 列出下载文件夹文件 |
| `open /System/Applications/TextEdit.app` | 打开文本编辑 |
| `open /System/Applications/Calculator.app` | 打开计算器 |
| `git` | 显示 git 帮助（走 stderr）|

## 已知问题

- 没有命令历史
- 没有 Tab 补全（已从界面删掉，实际上就是被砍了）

## 开发故事

AI 写代码，人类提需求，一下午搞定。这就是 2026 年的开发方式。

## 许可证

MIT License
