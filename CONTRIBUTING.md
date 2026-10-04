# Contributing to RunProcess

Thanks for your interest in improving RunProcess. This document describes how to report bugs, suggest features, and submit code.

---

## Ways to Contribute

- **Report a bug** – Open an issue with reproduction steps
- **Suggest a feature** – Open an issue describing the use case
- **Fix a bug** – Submit a pull request
- **Improve docs** – README, help content, translations
- **Add a translation** – New languages welcome

---

## Before You Start

- Search [existing issues](https://github.com/CaoHaoran-Dev/RunProcess/issues) to avoid duplicates
- For large changes, open an issue first to discuss the approach
- Read the [README](README.md) to understand the project's scope

### Out of Scope

RunProcess is a **lightweight command launcher**, not a terminal emulator. The following are intentionally not supported:

- Interactive TUI programs (vim, top, less, ssh sessions)
- Full terminal emulation (ANSI cursor movement, screen clearing)
- Cloud sync of history or aliases

If you want these, consider a dedicated terminal app.

### Planned, But Not Yet

These are on the roadmap but not implemented. Please open an issue to discuss design before submitting code:

- **Plugin system** – Let third parties extend RunProcess with custom commands, completion sources, or UI panels. The core team builds the plugin API, loader, and sandbox; individual plugins are maintained by the community.
- Command snippets – Save multi-line scripts for one-keystroke execution
- Output folding for long results
- Long-command completion notifications

---

## Reporting Bugs

A good bug report includes:

1. **What you did** – exact command or UI steps
2. **What you expected** – the behavior you wanted
3. **What happened** – the actual behavior, including error messages
4. **Environment**:
   - macOS version (e.g. macOS 14.5)
   - RunProcess version (from About window, e.g. `3.2.0 (1)`)
   - Chip: Apple Silicon or Intel
   - Session mode on or off
   - Appearance style

**If the app crashes**, attach the crash log from:

```
~/Library/Logs/DiagnosticReports/
```

Look for files starting with `RunProcess-`.

**If the issue is about command output**, include the exact command. Redact sensitive paths.

---

## Suggesting Features

Open an issue with the `enhancement` label. Describe:

- **The problem** – what's annoying or missing today
- **Your proposed solution** – how you'd like it to work
- **Alternatives you considered** – other ways to solve it

Concrete use cases beat abstract ideas. "I run `docker ps` ten times a day and want a one-keystroke alias" is better than "add aliases".

---

## Development Setup

### Requirements

- macOS 12.4 or later
- Xcode 16.0 or later
- Swift 5.9+ (bundled with Xcode)

### Clone and Build

```bash
git clone https://github.com/CaoHaoran-Dev/RunProcess.git
cd RunProcess
open RunProcess.xcodeproj
```

In Xcode:

1. Select the `RunProcess` scheme
2. Build (`⌘B`) and run (`⌘R`)

The app launches as a menu bar accessory. Look for the ⚡ icon.

### Dependencies

Managed via Swift Package Manager:

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) – global hotkey
- [Yams](https://github.com/jpsim/Yams) – YAML parsing for aliases and history

Xcode resolves them automatically on first build.

### Tests

```bash
xcodebuild test \
  -project RunProcess.xcodeproj \
  -scheme RunProcess \
  -destination "platform=macOS,arch=arm64"
```

CI runs the same on both `arm64` and `x86_64` for every PR.

---

## Code Style

### General

- Follow the existing style. When in doubt, match nearby code
- Prefer clarity over cleverness
- Comment non-obvious logic; skip obvious comments
- Keep functions small and focused

### Swift Conventions

- **Indentation**: 4 spaces, no tabs
- **Line length**: aim for 120 characters; hard limit at 150
- **Naming**: `UpperCamelCase` for types, `lowerCamelCase` for members
- **Access control**: prefer `private` by default, widen only when needed
- **Optionals**: avoid force unwrap (`!`) except where invariants are obvious
- **Concurrency**: mark data types `nonisolated` when they're used off the main actor; use `@MainActor` for UI

### SwiftUI

- One view per file when possible
- Extract subviews instead of deeply nesting `body`
- Use `@State` for view-local state, `@ObservedObject` for shared models
- Prefer `.sheet(item:)` over `.sheet(isPresented:)` when the content depends on optional data

### Localization

**All user-facing strings must be localized.**

- Use `NSLocalizedString("key", comment: "")` in Swift
- Add the key to all three files:
  - `RunProcess/Resources/Localizable/en.lproj/Localizable.strings`
  - `RunProcess/Resources/Localizable/zh-Hans.lproj/Localizable.strings`
  - `RunProcess/Resources/Localizable/zh-Hant.lproj/Localizable.strings`
- Group keys by feature (e.g. `settings.aliases.*`)
- Save all `.strings` files as **UTF-8 without BOM**

Forgetting a translation will break the build in subtle ways. Check all three files.

### Comments

Comments are in Chinese in most of the codebase. That's fine. Write comments in whichever language you're more comfortable with; reviewers can read both.

---

## Pull Requests

### Before Submitting

- [ ] The project builds without warnings
- [ ] Tests pass locally
- [ ] New user-facing strings are localized in all three languages
- [ ] You've tested the change manually (cold start, window behavior, etc.)
- [ ] If you changed storage format, old data migrates without loss

### PR Description

Use a clear title and describe:

1. **What** the change does
2. **Why** it's needed (link to the issue if applicable)
3. **How** you tested it
4. **Screenshots** for UI changes
5. **Breaking changes**, if any

### Commit Messages

Short imperative subject line, optional body:

```
Fix window closing immediately on launch

The didResignActive notification fired before the first window
became key, causing hideAllWindows() to run on a fresh session.
Guard with hasBeenActive flag.

Closes #42
```

Avoid `fix stuff` or `update`. Explain *what* and *why*.

### Review Process

- Maintainer reviews within a few days
- Address feedback with new commits; don't force-push during review
- Once approved, maintainer squashes and merges

---

## Adding a Translation

RunProcess currently supports:

- English (`en`)
- Simplified Chinese (`zh-Hans`)
- Traditional Chinese (`zh-Hant`)

To add a new language:

1. Create `RunProcess/Resources/Localizable/<code>.lproj/Localizable.strings`
2. Copy the English version
3. Translate all values, keep the keys unchanged
4. Ensure the file is UTF-8 without BOM
5. Test: switch system language, restart the app

Use the standard [BCP 47](https://en.wikipedia.org/wiki/IETF_language_tag) code (e.g. `ja`, `de`, `fr`).

---

## Storage Format

RunProcess stores user data in:

```
~/Library/Application Support/RunProcess/
├── aliases.yml      # command aliases
└── history.yml      # command history (max 500 entries)
```

Format is YAML. Older JSON files (`aliases.json`, `history.json`) are migrated automatically on first launch.

If you change the schema:

- Bump the file format in a way that reads old data
- Test migration with a real old file
- Don't silently discard user data

---

## Release Process

Maintainer-only, but documented here for transparency:

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist`
2. Update README if features changed
3. Commit with message `Release vX.Y.Z`
4. Tag: `git tag -a vX.Y.Z -m "RunProcess vX.Y.Z"`
5. Push tag: `git push origin vX.Y.Z`
6. On GitHub, create a Release with:
   - Title: `RunProcess vX.Y.Z`
   - Bilingual notes (English first, then Chinese)
   - Attached `RunProcess.zip`
7. Archive with `xcodebuild archive` and notarize if credentials available

---

## Code of Conduct

Be civil. Disagree about code, not people. Assume good faith. If something feels off, email the maintainer directly.

No harassment, discrimination, or personal attacks. Violations result in a ban.

---

## Questions

- **General questions**: open a [Discussion](https://github.com/CaoHaoran-Dev/RunProcess/discussions)
- **Bug reports**: open an [Issue](https://github.com/CaoHaoran-Dev/RunProcess/issues)
- **Security issues**: email the maintainer privately instead of opening a public issue

---

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE.md).

MIT © 2026 CaoHaoran-Dev

