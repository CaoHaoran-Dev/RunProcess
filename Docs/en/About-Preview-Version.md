# About Preview Version

> English · [简体中文](zh-Hans/About-Preview-Version.zh-Hans.md) · [繁體中文](zh-Hant/About-Preview-Version.zh-Hant.md)

RunProcess ships a **Preview** build alongside the stable release. Both builds carry the same feature set; the Preview build is where upcoming changes land first, so it can be unstable. This page explains what is different, how to install it, and what to include when reporting issues.

---

## What's different

| | Stable | Preview |
| :--- | :--- | :--- |
| Data directory | `~/Library/Application Support/RunProcess/` | `~/Library/Application Support/RunProcess-Beta/` |
| UserDefaults keys | no prefix | `beta.` prefix |
| Update feed | `appcast.xml` | `appcast-beta.xml` |
| Features | — | same as stable, plus work in progress |
| Wire protocol | stable within a release | may change between Preview builds |

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

- The Preview build comes from the same sources; the `BETA` compile flag only selects the data directory, the UserDefaults prefix and the update feed.
- Remote features require the same version on both ends. The wire protocol is not stable across Preview versions.
- Data written by the Preview build is not automatically migrated to the stable build.
- The Preview build is not notarized, same as the stable release.
- If you hit an issue that only happens in Preview, include the build number from the About window and the log lines starting with `🌐`, `🔌`, `📨`, `✅`, `⚠️` in your report.
- When using Shortcuts to run remote commands, macOS may restrict loopback connections (`127.0.0.1`) under sandbox rules. If you encounter a timeout, try using your Mac's local network IP (e.g., `192.168.x.x`) instead.
