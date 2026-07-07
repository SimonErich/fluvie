# Untrusted render security

The Playground and the `fluvie_server` render endpoints compile and run
**untrusted user code and specs**. This page records the threat model, the
result of a four-round red-team, and what remains to do. Read it before you
change anything under `fluvie_server/lib/src/api/render/` or the capture harness.

## Verdict

**The untrusted-render boundary is not sound, and it cannot be made sound by
patching individual seams.** A submitted `Video build()` snippet is JIT-run with
full VM privileges inside `flutter test`. Its only containment is an import
allowlist (`code_import_policy.dart`) plus a per-loader `FLUVIE_BLOCK_FILE_SOURCES`
flag. That model is the wrong layer: the allowed `package:flutter` surface reaches
the filesystem and network on its own, without any `dart:io` import.

**Do not expose the Playground to untrusted input until the render runs under
OS-level sandboxing.** The in-process checks below are defense in depth, not a
boundary.

## Threat model

- Trusted: a `KeyRenderRequest` (a bundled, developer-authored lesson).
- Untrusted: `Code`, `Spec`, `Prompt`, and `Edit` requests, and the
  `/v1/validate` + MCP `validate_code` paths.
- The attacker controls the Dart snippet or the spec JSON. The snippet must be a
  zero-arg synchronous top-level `Video build()`; it may import only allowlisted
  libraries. That is not a real restriction (see below).

## Confirmed exploits (executed against the live code)

The red-team wrote proofs and ran them. These are facts, not theory.

**Reachable with only allowlisted `package:flutter` + `package:fluvie/fluvie.dart`
imports:**

- `rootBundle.loadString('/etc/passwd')` (flutter/services) returns the file.
  Under `flutter test` the `flutter/assets` channel resolves the key as a raw
  path, with absolute paths and `../` traversal. Arbitrary host-file read.
- `NetworkImage(url)` inside `compute()` (flutter/foundation + flutter/painting)
  performs an outbound request. `compute` runs in a fresh isolate where
  flutter_test's mock `HttpOverrides` does not apply, so the request leaves the
  host. SSRF and exfiltration.
- A `fluvie` `Image.file(path)` wrapped in a plain `flutter.Builder` (invisible to
  the media collect walk) under a nested `RenderModeContext(mode: preview)`
  reaches the paint-time preview fallback, a raw `dart:io` file read that the
  loader-level `FLUVIE_BLOCK_FILE_SOURCES` never sees.

**Availability / integrity:**

- 64-bit integer overflow defeats the canvas bounds: `width = height = 2^32`
  makes `width * height` wrap to 0 and pass. Fixed (per-axis check).
- `renderPosterPng` is a second capture entrypoint that never calls the canvas
  guard and drives `boundary.toImage()` straight from the untrusted `baseSpec`.
- The parser-DoS pre-scan (`_nestsPastLimit`) counts only bracket depth, so a
  bracket-free deep AST (a long cascade `o..a..a...`, an elseless collection-`if`)
  under the size cap still burns seconds of synchronous CPU in `parseString`.
- `/v1/validate` and MCP `validate_code` run the analyzer on untrusted input with
  no complexity guard at all, on the main server isolate (~38 s measured for a
  ~60 KB payload). Code and spec renders are not rate-limited.

Earlier rounds also found: a bypassable regex allowlist (now AST-based), and the
allowlist trusting all of `package:fluvie/` including the private `src/` tree,
which exposed `IoProcessRunner.run` (RCE) and `readFileBytes` (file read). Both
fixed.

## Root cause

Containment is inherited from `flutter_test`'s incidental mocking or from
string-level import filtering, never owned by Fluvie at the IO and allocation
layer. String filtering cannot enumerate every capability of the allowed
framework surface, and `flutter_test`'s mocks do not survive `Isolate.run`.

## Required remediation (in priority order)

1. **Run every untrusted render and every untrusted analysis in an OS sandbox**:
   a locked-down process or container with no filesystem access beyond a scratch
   dir, no network, dropped privileges (seccomp / gVisor / a container with
   `--network none` and a read-only rootfs). This is the actual boundary; the
   import allowlist becomes one layer inside it.
2. **Parse untrusted code off the request isolate with a hard wall-clock budget**
   (import scan and `/v1/validate`), so any pathological input is bounded
   regardless of structure. Rate-limit code and spec renders like prompt/edit.
3. If any in-process mitigation must stand before (1): install process-wide
   `HttpOverrides` and an asset-channel handler that hard-fail under the untrusted
   define, latch capture mode from the root so a nested `RenderModeContext` cannot
   downgrade it, and narrow the flutter allowlist. Treat each as partial.

## What is hardened in-process today

Defense in depth only, all under `FLUVIE_BLOCK_FILE_SOURCES` / the render path:

- Import allowlist is AST-based and grants only the public `fluvie.dart` barrel
  and flutter non-`src/` libraries (`code_import_policy.dart`).
- `FileSource` is blocked at every media loader on the untrusted path.
- Canvas and frame-count bounds are overflow-safe and per-axis, enforced at the
  capture chokepoint (`render_harness.dart` `assertRenderWithinBounds`).
- A linear nesting pre-scan rejects bracket bombs before the parse (partial: see
  the cascade/collection-`if` bypass above).

## Where to next

- [Testing policy](testing.md)
- [Coverage](coverage.md)
