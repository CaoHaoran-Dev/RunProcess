# RunProcess 3.6.0 RC.1

> English · [简体中文](zh-Hans/Release-Notes-3.6.0-RC.1.zh-Hans.md) · [繁體中文](zh-Hant/Release-Notes-3.6.0-RC.1.zh-Hant.md)

Release candidate for the Preview channel. The stable build stays on 3.5.0; this build is `RunProcess Preview.app` and uses its own data directory.

---

## What's in this build

- **Remote execution** — Pair a Mac, then run commands on it from another Mac's command window, the menu bar's Remote submenu, or Shortcuts.
- **Workflows** — Multi-line scripts stored in `workflows.yml`, triggered by a short name.
- **Remote access policy** — Per-capability permissions plus blocked words, enforced on the host side.
- **Pairing notifications** — The 6-digit pairing code arrives as a system notification, with an in-app alert as fallback.
- **Remote App Intents** — `Run Remote Command` and `Search Remote History` for Shortcuts and Siri.

---

## Behavior changes to review before installing

### Remote permissions now default to deny

In previous Preview builds, enabling **Allow remote control** granted every capability by default (command execution, root, aliases, history, file access). From RC.1, the default is **nothing allowed**; the host rejects every remote request until you enable capabilities explicitly in **Settings → Remote → Remote Permissions**.

If you are upgrading and depended on the old default, open that page once and check what you actually need. While nothing is enabled, the Remote settings page shows a warning and no remote command will work.

### Remote build requires the same version on both ends

The wire protocol is not stable across Preview versions. Update both the controller and the host to RC.1 together.

---

## Quality work in this candidate

- **CI now builds the Release configuration.** The previous workflow ran the "Release" step without `-configuration Release`, so it built Debug — and a failure there could be masked because the script did not stop on error. Both schemes are now built in Release and tested in Debug for arm64 and x86_64.
- `CommandExecutor` no longer uses a single global "current task". Concurrent executions (two windows running sudo, or Shortcuts while a window is running) no longer cancel each other; cancellation is scoped to the execution that asked for it.
- The completion popup is per window instead of a shared singleton, so it no longer follows whichever window asked last.
- Debug logging no longer prints user commands or client token hashes; per-frame connection tracing is Debug-only.

---

## Known issues

- **Intermittent `swift-frontend` crash when building the Preview target in Release** with Xcode 26.3 on Intel: the compiler aborts inside its SIL optimizer (`DeadFunctionAndGlobalElimination` / `objCBridgingOptimization`) with a null dereference or heap corruption. Rebuilding usually succeeds; clean rebuilds passed repeatedly afterwards. CI builds with Xcode 26.5, where this has not been observed. If a local Release build fails this way, re-run it.
- Building the Release configuration requires a retry-free toolchain; see above.

---

## Installing

1. Unzip `RunProcess-Preview.zip` and move `RunProcess Preview.app` to `Applications`.
2. If macOS blocks the first launch, allow it in **System Settings → Privacy & Security**.
3. The build is not notarized, same as the stable release.

Data for this build lives in `~/Library/Application Support/RunProcess-Beta/`.
