# RunProcess 3.6.0

> English · [简体中文](../../../zh-Hans/Releases-Notes/Stable/Release-Notes-3.6.0.zh-Hans.md) · [繁體中文](../../../zh-Hant/Releases-Notes/Stable/Release-Notes-3.6.0.zh-Hant.md)

## Added

- **Remote Execution** - Pair another Mac and run commands on it from the same window, including workflows and sudo. Previously Preview-only, now part of the release build.
- **Workflows** - Multi-line scripts stored in `workflows.yml`, triggered by a short name. They rank above aliases in completion and expand before execution.
- **Remote Access Policy** - The host decides what a remote client may do, per capability: execute commands, run workflows, run as root, modify aliases, read or clear history, access files. Commands containing a blocked word are rejected.
- **Pairing Notifications** - The 6-digit pairing code arrives as a system notification, with an in-app alert when notifications are unavailable.
- **Remote App Intents** - Run Remote Command and Search Remote History are available to Shortcuts and Siri.
- **Remote Execution Help** - A new help topic covers host setup, pairing, host switching, permissions and reconnecting.

## Changed

- **Remote Permissions Default to Deny** - Turning on remote control no longer grants anything. Enable what you need in Settings > Remote > Remote Permissions; until then every remote request is rejected.
- **Notification Permission Timing** - The app no longer asks for notification permission on first launch. It asks when you enable remote control, the only feature that uses notifications.
- **Reconnect After Enabling** - After remote control is turned on, the other Mac must reconnect: run the command again in its window, or open a new window there. Host switching works the other way round: the menu bar selection applies to every open window, while a new window starts on the local Mac.
- **Same Version on Both Macs** - The remote wire protocol is not stable across releases; update both ends together.
- **Scrollbars** - Settings and Help use overlay scrollers that fade out when idle, and their scroll views no longer paint a white track over the glass background.

## Fixed

- **Concurrent Commands** - Running sudo in two windows, or Shortcuts while a window is busy, no longer cancels the other execution. Cancellation is scoped to the execution that asked for it.
- **Completion Popup** - The popup is per window instead of a shared singleton, so it no longer follows whichever window asked last.
- **Window Shadow** - Transparent windows kept their shadow at the old position after a resize; it is now recalculated whenever the window changes size.
- **Log Privacy** - Debug output no longer includes the commands you run or client token hashes.
- **Localization** - The workflow completion subtitle and the unexpected-handshake error were hard-coded Chinese and are now localized.
- **Release Builds in CI** - CI now actually builds the Release configuration; the previous workflow built Debug and could pass even when a Release build failed.

## Migration

From 3.5.0: nothing to migrate. Existing `aliases.yml`, `history.yml` and `paths.yml` continue to work; `workflows.yml`, `remote_hosts.yml`, `paired_clients.yml` and `remote_access.yml` are created on first use.

From the Preview build: the two builds keep separate data directories (`RunProcess` and `RunProcess-Beta`), so aliases, history, workflows and paired hosts are not carried over. Re-pair remote hosts after switching.

Remote control is off by default. If you turn it on, grant capabilities explicitly.

## Note

The app is not notarized by Apple. On first launch, right-click the app, select Open, and confirm.

Update packages are EdDSA-signed and verified before installation. Passwords and signing keys are never stored or transmitted.

Requires macOS 13.0 or later.
