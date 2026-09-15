# RunProcess

> A Spotlight-style command launcher for macOS with a translucent interface and menu bar integration.

---

## Overview

RunProcess is a lightweight macOS application that provides a quick command execution interface inspired by the Windows Run dialog. It combines the power of `/bin/zsh` with a polished, modern interface that remains accessible from the menu bar at all times.

---

## Features

- **Command Execution** – Execute any shell command with real-time output display
- **Tab Completion** – Auto-complete system commands, command history, and file paths
- **Command History** – Navigate previous commands using the ↑ and ↓ arrow keys
- **Drag & Drop** – Drag files from Finder to automatically populate file paths with proper escaping
- **Root Privileges** – Execute commands with `sudo` via a secure password dialog. The password is used only in memory during execution and is never stored or logged
- **Global Hotkey** – Show or hide the window from anywhere with ⌘⌥R (customizable in Settings)
- **Menu Bar Integration** – Access from the menu bar; the Dock icon is hidden
- **Multiple Appearance Modes** – Choose between None, Frosted Glass, and Liquid Glass (macOS 26 and later)
- **Floating Window** – Spotlight-style floating window
- **Multi-line Input** – Support for multi-line commands with Shift+Enter
- **Multiple Windows** – Each window is an independent session
- **Session Mode (Optional)** – Persistent shell; `cd` and `export` persist across commands
- **Custom Working Directory** – Configure the default working directory for new windows
- **Automatic Hide on Deactivate** – Windows hide automatically when the application loses focus

---

## Usage

Open the application, click ⚡ in the menu bar, type a command, and press Enter.

| Input | Result |
|-------|--------|
| `ls ~/Downloads` | List files |
| `open .` | Open the current directory in Finder |
| `git status` | Show Git status |
| `/System/Applications/Calculator.app` | Automatically prefixed with `open`, launches Calculator |

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `⌘⌥R` | Show or hide the window globally (customizable in Settings) |
| `⌘N` | New window |
| `Enter` | Execute |
| `Shift+Enter` | Newline |
| `Tab` | Completion popup |
| `↑` `↓` | Command history navigation |
| `⌘W` | Hide window |
| `⌘Q` | Quit |

---

## Appearance

Three appearance modes are available in **Settings → Appearance**:

| Mode | Description | Availability |
|------|-------------|--------------|
| None | Solid system window background | macOS 12.4 and later |
| Frosted Glass | `NSVisualEffectView` blur | macOS 12.4 and later |
| Liquid Glass | Native Liquid Glass material | macOS 26 and later |

The default is Frosted Glass on macOS 15 and earlier, and Liquid Glass on macOS 26 and later. The Liquid Glass option is hidden on systems that do not support it.

---

## Window Behavior

By default, all windows hide automatically when the application loses focus, matching the behavior of Spotlight. This can be disabled in **Settings → Window**.

---

## Session Mode

Enable in **Settings → Session**. This only affects newly opened windows.

In session mode, each window maintains a long-running `zsh` process. Commands such as `cd` and `export` persist across subsequent commands within the same window, providing behavior closer to a real terminal.

The window title in session mode displays `RunProcess - Session — <current directory>`.

| Behavior | Non-session | Session |
|----------|-------------|---------|
| After `cd` | Still in the default working directory | Switched to the new directory |
| After `export` | Environment variable is lost | Environment variable is retained |
| Startup overhead | A new shell per command | One shell, reused |
| Isolation | Fully isolated | Shared state within the session |

---

## Working Directory

Configure in **Settings → Working Directory**. If not set, the user's home directory is used.

This only affects newly opened windows. Windows that are already open retain the working directory of their existing shell.

If the configured path no longer exists, the application falls back to the home directory and displays a warning in Settings.

---

## Sudo

Enable "Run as root" before executing a command to receive a password prompt.

Every sudo command requires entering the password again. The password is used only in memory during execution and is never stored or logged.

---

## Language

RunProcess supports English, Simplified Chinese, and Traditional Chinese. To use a different language for RunProcess only, go to **System Settings → General → Language & Region → Applications** and select RunProcess. This feature requires macOS 13 or later.

---

## Requirements

- macOS 12.4 or later
- Apple Silicon or Intel

---

## Installation

### Download (Recommended)

Download the latest `RunProcess.zip` from [Releases](https://github.com/CaoHaoran-Dev/RunProcess/releases).

1. Download and unzip the file.
2. Move `RunProcess.app` to your `Applications` folder.
3. Right-click the application → **Open** → confirm to bypass Gatekeeper.

> The application is not notarized, so macOS may display a security warning on first launch. Right-click and select **Open** to run it.

### Build from Source

```bash
git clone https://github.com/CaoHaoran-Dev/RunProcess.git
cd RunProcess
open RunProcess.xcodeproj
```

Requires Xcode 16.0 or later.

### Try It Online

Visit the GitHub Pages demo:
[https://CaoHaoran-Dev.github.io/RunProcess-WebDemo/](https://CaoHaoran-Dev.github.io/RunProcess-WebDemo/)

---

## Tech Stack

Swift and SwiftUI

---

## Documentation

- [简体中文 README](Docs/zh-Hans/README.zh-Hans.md)
- [繁体中文 README](Docs/zh-Hant/README.zh-Hant.md)
- [License](LICENSE.md)

---

## License

MIT © 2026 CaoHaoran-Dev
