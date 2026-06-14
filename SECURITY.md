# Security Policy

## Supported versions

The latest `0.x` release receives security fixes. Older builds do not. Once
`1.0` ships, the current major line will be supported.

## Reporting a vulnerability

Use GitHub's [private vulnerability reporting](https://github.com/SimonErich/fluvie/security/advisories/new)
to open a report, or email **simon.auer@marqably.com** if you prefer. Include a
description and, if possible, a minimal reproduction. Please do not open a public
issue for security reports. You will get an acknowledgement within a few days.

## Design guarantees you can hold us to

- FFmpeg is always invoked with **argument lists**, never shell strings. No
  user-supplied path or URL is ever concatenated into a command line.
- External inputs (URLs, file paths, downloaded media, HTML/Mermaid sources)
  are validated before use.
- Network fetches and webview/diagram snapshots honor a strict **allowlist**
  and run time-boxed in a sandboxed environment.
- Temp files live in sandboxed, per-render directories.

If you find code that violates one of these, that is a reportable bug even
without a worked exploit.
