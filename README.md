# RunProcess

> A Spotlight-style command launcher for macOS with a translucent interface and menu bar integration.

---

## Overview

RunProcess is a lightweight macOS application that provides a quick command execution interface inspired by the Windows Run dialog. It combines the power of `/bin/zsh` with a polished, modern interface that stays accessible from your menu bar.

---

## Features

- **Command Execution** – Execute any shell command with real-time output display
- **Tab Completion** – Auto-complete system commands, command history, and file paths
- **Command History** – Navigate previous commands using ↑ and ↓ arrow keys
- **Drag & Drop** – Drag files from Finder to automatically populate file paths with proper escaping
- **Root Privileges** – Execute commands with `sudo` via a secure password dialog (password never stored or logged)
- **Global Hotkey** – Show/hide the window with ⌘⌥R from anywhere
- **Menu Bar Integration** – Access from the menu bar; Dock icon is hidden
- **Translucent Interface** – Native macOS visual effect with automatic light/dark mode adaptation
- **Floating Window** – Spotlight-style window that stays on top
- **Multi-line Input** – Support for multi-line commands with Shift+Enter

---

## Requirements

- macOS 12.4 or later
- Apple Silicon or Intel

---

## Installation

### Download (Recommended)

Download the latest `RunProcess.zip` from [Releases](https://github.com/CaoHaoran-Dev/RunProcess/releases).

1. Download and unzip the file
2. Move `RunProcess.app` to your `Applications` folder
3. Right-click the app → **Open** → confirm to bypass Gatekeeper

> The app is not notarized, so macOS may show a security warning on first launch. Right-click and select **Open** to run it.

### Build from Source

```bash
git clone https://github.com/CaoHaoran-Dev/RunProcess.git
cd RunProcess
open RunProcess.xcodeproj
```

Requires Xcode 16.0+.

---

## Documentation

- [简体中文 README](Docs/zh-Hans/README.md)
- [License](LICENSE.md)

---

## License

MIT © CaoHaoran-Dev
