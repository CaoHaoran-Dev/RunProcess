# RunProcess 3.6.0

> English · [简体中文](zh-Hans/Release-Notes-3.6.0.zh-Hans.md) · [繁體中文](zh-Hant/Release-Notes-3.6.0.zh-Hant.md)

Remote execution and workflows, previously available only in the Preview build, are now part of the release build.

---

## New

- **Remote execution** — Pair another Mac and run commands there from the same command window. Pairing uses a 6-digit code delivered as a system notification; paired hosts also show up through Bonjour discovery in the menu bar.
- **Workflows** — Multi-line scripts stored in `workflows.yml`, triggered by a short name. They complete alongside aliases and history, and expand before execution.
- **Remote access policy** — The host decides what a remote client may do, per capability: execute commands, run workflows, run as root, modify aliases, read or clear history, access files. Commands containing a blocked word are rejected.
- **Remote App Intents** — `Run Remote Command` and `Search Remote History` for Shortcuts and Siri.
- **Remote Execution help topic** — The in-app help (`⌘/`) documents the host, pairing, host switching, permissions and reconnecting.

---

## Security and behavior changes

### Remote permissions start denied

Remote control is **off by default**, and once it is on, **no capability is allowed** until you enable it in **Settings → Remote → Remote Permissions**. Earlier Preview builds granted everything by default; that was too broad for a release build, so the default is now fail-closed. While nothing is enabled, the Remote settings page shows a warning and every remote request is rejected.

### Notification permission is requested when you enable remote control

The app no longer asks for notification permission on first launch. The prompt appears when you turn on **Allow Remote Control**, which is the only feature that uses notifications (the pairing code). If notifications are declined, the code is still shown in an in-app alert.

### After enabling remote control, the other Mac must reconnect

Run the command again in its window, or open a new window there. Connections established before the change are not refreshed automatically. Host switching works the other way around: the menu bar's Remote submenu applies to every open window, while a newly opened window starts on the local Mac.

### Remote features need the same version on both ends

The wire protocol is not stable across releases. Update both Macs together.

---

## Execution fixes

- `CommandExecutor` no longer keeps a single global "current task". Concurrent runs (two windows running sudo, or Shortcuts while a window is running) no longer cancel each other, and cancellation is scoped to the execution that requested it.
- The completion popup is per window instead of a shared singleton, so it no longer follows whichever window asked last.
- Debug logging no longer prints user commands or client token hashes, and per-frame connection tracing is Debug-only.

---

## Building from source

CI now builds the **Release** configuration for both schemes; the previous workflow built Debug and could pass even when a Release build failed. Tests still run in Debug, where `@testable` requires `-enable-testing`.

---

## Upgrading from the Preview build

The two builds keep separate data: `~/Library/Application Support/RunProcess/` for this release and `RunProcess-Beta/` for the Preview. Aliases, history, workflows, and paired hosts do not carry over, so **re-pair remote hosts** after switching. You can run both side by side.

---

## Known issues

- Building the Preview target in the Release configuration with **Xcode 26.3 on Intel** can crash `swift-frontend` intermittently inside the SIL optimizer. Rebuilding usually succeeds. CI uses Xcode 26.5, where this has not been observed.
- The application is not notarized; on first launch, allow it in **System Settings → Privacy & Security**.
