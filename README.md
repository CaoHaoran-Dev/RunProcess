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
- **Root Privileges** – Execute commands with `sudo` via a secure password dialog (password is used only in memory during execution, never stored or logged)
- **Global Hotkey** – Show/hide the window with ⌘⌥R from anywhere (customizable in Settings)
- **Menu Bar Integration** – Access from the menu bar; Dock icon is hidden
- **Translucent Interface** – Native macOS visual effect with automatic light/dark mode adaptation
- **Floating Window** – Spotlight-style window that stays on top
- **Multi-line Input** – Support for multi-line commands with Shift+Enter
- **Multiple Windows** – Each window is an independent session
- **Session Mode (Optional)** – Persistent shell; `cd` / `export` persist across commands
- **Custom Working Directory** – Configure the default working directory for new windows

---

## Usage

Open the app, click ⚡ in the menu bar, type a command, and press Enter.

| Input | Result |
|-------|--------|
| `ls ~/Downloads` | List files |
| `open .` | Open current directory in Finder |
| `git status` | Git status |
| `/System/Applications/Calculator.app` | Auto-prefixed with `open`, launches Calculator |

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `⌘⌥R` | Show/hide window globally (customizable in Settings) |
| `⌘N` | New window |
| `Enter` | Execute |
| `Shift+Enter` | Newline |
| `Tab` | Completion popup |
| `↑↓` | Command history navigation |
| `⌘W` | Hide window |
| `⌘Q` | Quit |

---

## Session Mode

Enable in **Settings → Session**. Only affects **newly opened windows**.

In session mode, each window holds a long-running `zsh` process. Commands like `cd` and `export` persist across subsequent commands in that window, behaving more like a real terminal.

The window title in session mode shows `RunProcess - Session — <current directory>`.

Differences between session mode and non-session mode:

| Behavior | Non-session | Session |
|----------|-------------|---------|
| After `cd` | Still in default working directory | Switched to new directory |
| After `export` | Environment variable lost | Environment variable retained |
| Startup overhead | New shell per command | One shell, reused |
| Isolation | Fully isolated | Shared state within session |

---

## Working Directory

Configure in **Settings → Working Directory**. Defaults to your home directory if not set.

Only affects **newly opened windows**. Already-open windows keep their shell's working directory.

If the configured path no longer exists, it falls back to your home directory and a warning is shown in Settings.

---

## Sudo

Enable "Run as root" before executing a command to get a password prompt.

**Every sudo command requires entering your password.** The password is used only in memory during execution and is never stored or logged.

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

### Try It Online

Visit the GitHub Pages demo:
[https://CaoHaoran-Dev.github.io/RunProcess-WebDemo/](https://CaoHaoran-Dev.github.io/RunProcess-WebDemo/)

---

## Tech Stack

Swift + SwiftUI, 100% AI-generated code

---

## Documentation

- [简体中文 README](Docs/zh-Hans/README.zh-Hans.md)
- [License](LICENSE.md)

---

## License

MIT © 2026 CaoHaoran-Dev
