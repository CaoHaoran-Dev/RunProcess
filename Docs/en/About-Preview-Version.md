# About Preview Version

> English · [简体中文](zh-Hans/About-Preview-Version.zh-Hans.md) · [繁體中文](zh-Hant/About-Preview-Version.zh-Hant.md)

RunProcess ships a **Preview** build alongside the stable release. It contains features that are still being tested and may change or be removed. This page explains what is different, how to install it, and what to include when reporting issues.

---

## What's different

| | Stable | Preview |
| :--- | :--- | :--- |
| Data directory | `~/Library/Application Support/RunProcess/` | `~/Library/Application Support/RunProcess-Beta/` |
| Update feed | `appcast.xml` | `appcast-beta.xml` |
| Remote connection | — | Pairing, Bonjour discovery, remote execution |
| Workflows | — | Multi-line scripts triggered by a short name |
| Remote access policy | — | Per-capability permissions and blocked words |
| Pairing notifications | — | System notifications with the 6-digit code |
| App Intents (Shortcuts) | Local execution | Local + Remote execution |

The Preview build uses a separate data directory and a separate UserDefaults key prefix, so it can be installed next to the stable release without conflicts.

---

## Download

[Download RunProcess-Preview.zip](https://downloads.caohaoran.dpdns.org/downloads/runprocess/RunProcess-Preview.zip)

You can also browse older versions on [GitHub Releases](https://github.com/CaoHaoran-Dev/RunProcess/releases).

1. Download and unzip the file.
2. Move `RunProcess Preview.app` to your `Applications` folder.
3. On first launch, go to **System Settings → Privacy & Security** and click **Open Anyway** if macOS shows a security warning.

---

## Notes

- Preview features are gated behind the `BETA` compile flag. They are not present in the stable build.
- Remote features require the same version on both ends. The wire protocol is not stable across Preview versions.
- Data written by the Preview build is not automatically migrated to the stable build.
- The Preview build is not notarized, same as the stable release.
- If you hit an issue that only happens in Preview, include the build number from the About window and the log lines starting with `🌐`, `🔌`, `📨`, `✅`, `⚠️` in your report.
- When using Shortcuts to run remote commands, macOS may restrict loopback connections (`127.0.0.1`) under sandbox rules. If you encounter a timeout, try using your Mac's local network IP (e.g., `192.168.x.x`) instead.
