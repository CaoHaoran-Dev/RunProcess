# RunProcess

> A Spotlight-style command launcher for macOS with a translucent interface and menu bar integration.

---

## Overview

RunProcess is a lightweight macOS application that provides a quick command execution interface inspired by the Windows Run dialog. It combines the power of `/bin/zsh` with a polished, modern interface that remains accessible from the menu bar at all times.

---

## Features

- **Command Execution** – Execute any shell command with real-time output display
- **ANSI Colors** – Output from `git status`, `ls -G`, `grep --color`, etc. is rendered with proper colors
- **Tab Completion** – Auto-complete aliases, command history, system commands, and file paths
- **Command History** – Navigate previous commands with ↑ / ↓, ranked by frecency (frequency × recency)
- **History Search** – Press ⌘R to fuzzy-search the entire history
- **Aliases** – Define short names like `gs` → `git status`; they appear first in completion
- **Drag & Drop** – Drag files from Finder to automatically populate file paths with proper escaping
- **Root Privileges** – Execute commands with `sudo` via a secure password dialog. The password is used only in memory during execution and is never stored or logged
- **Default Sudo** – Optionally lock the main window into "run as root" mode
- **Global Hotkey** – Show or hide the window from anywhere with ⌘⌥R (customizable in Settings)
- **Menu Bar Integration** – Access from the menu bar; the Dock icon is hidden
- **Multiple Appearance Modes** – None, Frosted Glass, and Liquid Glass (macOS 26 and later). Applies to the main window, Settings, Help, About, and dialogs
- **Floating Window** – Spotlight-style floating window
- **Multi-line Input** – Support for multi-line commands with Shift+Enter
- **Multiple Windows** – Each window is an independent session
- **Session Mode (Optional)** – Persistent shell; `cd` and `export` persist across commands
- **Custom Working Directory** – Configure the default working directory for new windows
- **Automatic Hide on Deactivate** – Windows hide automatically when the application loses focus
- **In-app Help** – Sidebar-based help window, styled like macOS Help Viewer
- **Localization** – English, Simplified Chinese, Traditional Chinese

---

## Usage

Open the application, click ⚡ in the menu bar, type a command, and press Enter.

| Input | Result |
|-------|--------|
| `ls ~/Downloads` | List files |
| `open .` | Open the current directory in Finder |
| `git status` | Show Git status (with colors) |
| `/System/Applications/Calculator.app` | Automatically prefixed with `open`, launches Calculator |

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `⌘⌥R` | Show or hide the window globally (customizable in Settings) |
| `⌘N` | New window |
| `⌘R` | Search command history |
| `⌘,` | Open Settings |
| `⌘/` | Open Help |
| `⌘W` | Hide window |
| `⌘Q` | Quit |
| `Enter` | Execute |
| `Shift+Enter` | Newline |
| `Tab` | Completion popup |
| `↑` `↓` | Command history navigation |

---

## Appearance

Three appearance modes are available in **Settings → Appearance**:

| Mode | Description | Availability |
|------|-------------|--------------|
| None | Solid system window background | macOS 12.4 and later |
| Frosted Glass | `NSVisualEffectView` blur | macOS 12.4 and later |
| Liquid Glass | Native Liquid Glass material | macOS 26 and later |

The default is Frosted Glass on macOS 15 and earlier, and Liquid Glass on macOS 26 and later. The Liquid Glass option is hidden on systems that do not support it.

The chosen style applies to the main window, Settings, Help, About, and the sudo password dialog.

---

## Window Behavior

By default, all windows hide automatically when the application loses focus, matching the behavior of Spotlight. This can be disabled in **Settings → General**.

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

## Command History

Every executed command is recorded. The history powers two features:

- **↑ / ↓ navigation** – ranked by frecency: frequently used and recently used commands rise to the top
- **⌘R search** – fuzzy matching across the whole history (`gst` matches `git status`)

History is stored at:

```
~/Library/Application Support/RunProcess/history.json
```

Maximum 500 entries. The oldest least-recently-used entries are pruned first.

Clear all history from the menu bar: **Clear Command History**.

---

## Aliases

Aliases let you define short names for frequently used commands. They rank above everything else in the completion popup.

Built-in examples:

| Alias | Expands to |
|-------|-----------|
| `gs` | `git status` |
| `gp` | `git pull --rebase` |
| `ll` | `ls -lah` |
| `serve` | `python3 -m http.server 8000` |

Custom aliases live in:

```
~/Library/Application Support/RunProcess/aliases.json
```

Format:

```json
[
  { "name": "gs", "expansion": "git status" },
  { "name": "serve", "expansion": "python3 -m http.server 8000" }
]
```

Restart the app after editing.

---

## Working Directory

Configure in **Settings → Working Directory**. If not set, the user's home directory is used.

This only affects newly opened windows. Windows that are already open retain the working directory of their existing shell.

If the configured path no longer exists, the application falls back to the home directory and displays a warning in Settings.

---

## Sudo

Enable "Run as root" before executing a command to receive a password prompt.

Every sudo command requires entering the password again. The password is used only in memory during execution and is never stored or logged.

### Default Sudo

In **Settings → Sudo**, enable **Always run as root** to lock the main window's sudo toggle to the on position. The toggle becomes read-only, marked with a solid lock icon. Every command still prompts for the password.

---

## Help

Press **⌘/** or choose **RunProcess Help** from the menu bar. The help window has a sidebar of topics:

- Overview
- Keyboard Shortcuts
- Command Tips
- Session Mode
- Running as Root
- Aliases
- Appearance

The sidebar has a search field to filter topics by title.

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

> The application is not notarized, so macOS may display a security warning on first launch. Go to **System Settings → Privacy & Security** and click **Open Anyway**.

### Homebrew

```bash
brew tap CaoHaoran-Dev/apptap
brew trust CaoHaoran-Dev/apptap
brew install runprocess
```

### Build from Source

```bash
git clone https://github.com/CaoHaoran-Dev/RunProcess.git
cd RunProcess
open RunProcess.xcodeproj
```

Requires Xcode 16.0 or later.

### Try It Online

Visit the GitHub Pages demo:
[RunProcess WebDemo](https://CaoHaoran-Dev.github.io/RunProcess-WebDemo/)

---

## Tech Stack

Swift and SwiftUI

---

## Documentation

- [简体中文 README](Docs/zh-Hans/README.zh-Hans.md)
- [繁体中文 README](Docs/zh-Hant/README.zh-Hant.md)
- [Contributing](CONTRIBUTING.md)
- [License](LICENSE.md)

---

## License

MIT © 2026 CaoHaoran-Dev
