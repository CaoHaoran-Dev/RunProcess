# Contributing to RunProcess

> English · [简体中文](Docs/zh-Hans/CONTRIBUTING.zh-Hans.md) · [繁體中文](Docs/zh-Hant/CONTRIBUTING.zh-Hant.md)

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

- Interactive TUI programs run in the foreground (vim, top, less, ssh sessions)
- Full terminal emulation (ANSI cursor movement, screen clearing)
- Cloud sync of history or aliases

Non-interactive uses of the same tools are fine — e.g. `echo x | less` or `ssh host 'uname -a'` (piped/redirected commands are not treated as interactive). If you need a real terminal, use a dedicated terminal app.

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
   - RunProcess version (from About window, e.g. `3.5.0 (1)`)
   - Chip: Apple Silicon or Intel
   - Session mode on or off
   - Appearance style
   - Shell selected in Settings
   - Whether the Preview/Beta build is involved

**If the app crashes**, attach the crash log from:

```
~/Library/Logs/DiagnosticReports/
```

Look for files starting with `RunProcess-`.

**If the issue is about command output**, include the exact command. Redact sensitive paths.

**If the issue is about remote features (Preview only)**, include the log lines starting with `🌐`, `🔌`, `📨`, `✅`, `⚠️` from Console.app.

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

- macOS 14.5 or later
- Xcode 16.0 or later
- Swift 5.9+ (bundled with Xcode)

> **Note:** CI uses Xcode 26 on `macos-26`. Building or testing Preview/Beta features may require a newer Xcode than the minimum above. If you only touch the stable target, Xcode 16.0 is sufficient.

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

To work on Preview/Beta features, select the `RunProcess Preview` scheme instead. It is compiled with the `BETA` flag and stores data in `RunProcess-Beta/`.

### Dependencies

Managed via Swift Package Manager:

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) – global hotkey
- [RemoteLinkKit](https://github.com/CaoHaoran-Dev/RemoteLinkKit) – remote connection
- [Sparkle](https://sparkle-project.org) – update delivery
- [Yams](https://github.com/jpsim/Yams) – YAML parsing for aliases and history

Xcode resolves them automatically on first build.

### Tests

The project has two test targets, each tied to its scheme. `RemoteConnectionTests` imports `RunProcess_Preview` and only compiles under the Preview scheme.

**Release (`RunProcessTests`):**

```bash
xcodebuild test \
  -project RunProcess.xcodeproj \
  -scheme RunProcess \
  -destination "platform=macOS,arch=arm64" \
  CODE_SIGNING_ALLOWED=NO
```

**Preview/Beta (`RunProcessPreviewTests`):**

```bash
xcodebuild test \
  -project RunProcess.xcodeproj \
  -scheme "RunProcess Preview" \
  -destination "platform=macOS,arch=arm64" \
  CODE_SIGNING_ALLOWED=NO
```

CI runs the same on both `arm64` and `x86_64` for every PR. Add `CODE_SIGNING_ALLOWED=NO` when running locally without a signing identity.

To run a single test class, add `-only-testing`:

```bash
xcodebuild test \
  -project RunProcess.xcodeproj \
  -scheme RunProcess \
  -destination "platform=macOS,arch=arm64" \
  -only-testing:RunProcessTests/ShellQuotingTests \
  CODE_SIGNING_ALLOWED=NO
```

---

## Code Style

### General

- Follow the existing style. When in doubt, match nearby code
- Prefer clarity over cleverness
- Comment non-obvious logic; skip obvious comments
- Keep functions small and focused

### Swift Conventions

- **Line length**: aim for 120 characters; hard limit at 150. Existing code has some longer lines — new code should stay within the limit, and touch-ups are welcome but not required.
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

A missing key does **not** fail the build — the app falls back to displaying the raw key at runtime. Check all three files manually before submitting.

### Comments

Comments are in Chinese in most of the codebase. That's fine. Write comments in whichever language you're more comfortable with; reviewers can read both.

---

## Pull Requests

### Before Submitting

- [ ] The project builds without warnings
- [ ] Tests pass locally for both Release and Preview schemes
- [ ] New user-facing strings are localized in all three languages
- [ ] You've tested the change manually (cold start, window behavior, etc.)
- [ ] If you changed storage format, old data migrates without loss
- [ ] If you changed remote protocol or policy, note the compatibility impact in the PR description

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

### Stable build

RunProcess stores user data in:

```
~/Library/Application Support/RunProcess/
├── aliases.yml      # command aliases
├── history.yml      # command history (max 500 entries)
└── paths.yml        # custom executable search paths
```

### Preview/Beta build

Stores data in `RunProcess-Beta/` instead, and adds:

```
├── workflows.yml         # multi-line scripts
├── remote_hosts.yml      # paired remote servers
├── paired_clients.yml    # clients paired to this Mac
└── remote_access.yml     # capability toggles + blocked words
```

`UserDefaults` keys are prefixed with `beta.` in the Preview build (`AppSettings.keyPrefix`), so the two builds do not share preferences.

Format is YAML. Older JSON files (`aliases.json`, `history.json`) are migrated automatically on first launch.

If you change the schema:

- Bump the file format in a way that reads old data
- Test migration with a real old file
- Don't silently discard user data
- Update this section if you add a new file

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
7. Archive with `xcodebuild archive`. Notarize if credentials are available; current public releases are **not** notarized, so users must use "Open Anyway" on first launch (see README).

---

## Code of Conduct

Be civil. Disagree about code, not people. Assume good faith. If something feels off, contact the maintainer privately via the contact details on the repository profile.

No harassment, discrimination, or personal attacks. Violations result in a ban.

---

## Questions

- **General questions**: open a [Discussion](https://github.com/CaoHaoran-Dev/RunProcess/discussions)
- **Bug reports**: open an [Issue](https://github.com/CaoHaoran-Dev/RunProcess/issues)
- **Security issues**: report privately via [GitHub Security Advisories](https://github.com/CaoHaoran-Dev/RunProcess/security/advisories/new). See [SECURITY.md](SECURITY.md) for details. Do not open a public issue for vulnerabilities.

---

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE.md).

MIT © 2026 CaoHaoran-Dev
