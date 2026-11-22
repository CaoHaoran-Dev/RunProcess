# Security Policy

> English · [简体中文](Docs/zh-Hans/SECURITY.zh-Hans.md) · [繁體中文](Docs/zh-Hant/SECURITY.zh-Hant.md)

## Supported Versions

Security fixes are provided for the latest released version of RunProcess.
Please make sure you are on the latest release before reporting.

## Reporting a Vulnerability

Please report security vulnerabilities **privately** via
[GitHub Security Advisories](https://github.com/CaoHaoran-Dev/RunProcess/security/advisories/new).

**Do not open a public issue for security problems.** Public disclosure before a
fix is available puts users at risk.

A useful report includes:

- Affected version (from the About window, e.g. `3.5.0 (1)`)
- macOS version and chip (Apple Silicon or Intel)
- Steps to reproduce
- Impact and any proof-of-concept
- Whether the issue is already public anywhere

## What to Expect

- We aim to acknowledge reports within a few days
- We will keep you updated on triage and the fix timeline
- We will credit you in the advisory unless you prefer to stay anonymous
- We may ask for more details or a reproduction

## Scope

RunProcess is a lightweight command launcher. In scope:

- The app itself (command execution, aliases, history, storage)
- Update delivery (Sparkle)
- Handling of user data under `~/Library/Application Support/RunProcess/`

Out of scope:

- Vulnerabilities in third-party dependencies (report upstream, but tell us too)
- Issues requiring an already-compromised machine
- Social engineering

## Disclosure

We follow coordinated disclosure. Once a fix is released, we publish a
GitHub Security Advisory describing the issue and the fixed version.

## Questions

For non-security questions, see [CONTRIBUTING.md](CONTRIBUTING.md).
