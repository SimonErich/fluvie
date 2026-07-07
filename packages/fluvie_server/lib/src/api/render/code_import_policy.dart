/// The Playground import allowlist: which libraries a submitted `Video build()`
/// snippet may `import`/`export`. Everything else is rejected before the code is
/// compiled or run.
///
/// Allowed:
/// - `package:fluvie/fluvie.dart` — the single public barrel ONLY. Not the
///   private `src/` tree (its `IoProcessRunner`/`readFileBytes` reach dart:io)
///   and not the low-level `rendering.dart` pipeline barrel.
/// - `package:flutter/<lib>.dart` — the framework's public libraries, but NOT
///   `package:flutter/src/`.
/// - `dart:math` and `dart:ui`.
///
/// Rejected: `dart:io`, `dart:ffi`, `dart:isolate`, `dart:mirrors`, any
/// `http`/network package, any third-party package, and any package's `src/`.
///
/// SECURITY WARNING — this allowlist is DEFENSE IN DEPTH, not a boundary. The
/// snippet is JIT-run with full VM privileges inside `flutter test`, and the
/// allowed `package:flutter` surface still reaches the filesystem and network
/// WITHOUT any `dart:io` import: `rootBundle` (flutter/services) reads arbitrary
/// host paths under the tester, `NetworkImage` (flutter/painting) performs
/// outbound requests, and `Image.file` reaches a raw file read. A red-team
/// executed all three. Do NOT rely on this allowlist alone to contain untrusted
/// code — the render must run under OS-level sandboxing (a locked-down
/// process/container with no filesystem or network and dropped privileges)
/// before the Playground is exposed to untrusted input. See
/// `documentation/contributing/untrusted-render-security.md`.
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// Libraries a snippet may import or export, matched exactly.
///
/// `package:fluvie` is granted ONLY through its single public barrel. Its
/// private `src/` tree and the low-level `rendering.dart` pipeline barrel are
/// deliberately excluded: they publicly re-export dart:io-backed helpers
/// (`IoProcessRunner.run` → `Process.run`, `readFileBytes` → `File.readAsBytes`,
/// the ffmpeg runners) as plain-`String` APIs, so allowing a `package:fluvie/`
/// sub-path would hand an untrusted snippet arbitrary process and file access
/// without it ever naming a blocked `dart:` library.
const Set<String> _allowedExact = {'dart:math', 'dart:ui', 'package:fluvie/fluvie.dart'};

/// Library prefixes a snippet may import or export. Only a package's PUBLIC
/// libraries are granted — never its private `src/` tree. The flutter framework
/// is pure UI (no filesystem or socket APIs) once `src/` is excluded.
const List<String> _allowedPrefixes = ['package:flutter/'];

/// The private sub-tree of any package: never importable, whatever the package.
const String _privateSubtree = 'src/';

/// The libraries [code] imports or exports that are not on the allowlist, in
/// source order with duplicates removed. Empty means the snippet's imports are
/// safe to compile.
///
/// The snippet is parsed with the real Dart front end (`parseString`), so every
/// `import`/`export` directive is seen exactly as the compiler will see it —
/// regardless of how many share a physical line, of leading block comments or
/// metadata annotations, or of adjacent-string URIs. A hand-rolled scan over the
/// source text cannot make that guarantee, and this is a security boundary: the
/// snippet runs as untrusted code, so a directive we fail to see is a directive
/// that reaches, say, `dart:io`. Every URI a directive names — including each
/// branch of a conditional `import '...' if (...) '...'` — is checked.
List<String> disallowedImports(String code) {
  // A cheap O(n) guard BEFORE the parse: the analyzer's error recovery is
  // super-linear in bracket-nesting depth, so a `{{{{…` bomb under the byte
  // limit would otherwise burn seconds of synchronous CPU on the request
  // isolate here, before the render is even enqueued. Reject it as unparseable.
  if (_nestsPastLimit(code)) return const [_tooDeeplyNested];
  // throwIfDiagnostics: false so a snippet that does not fully parse still
  // yields a best-effort unit; the directives the parser does recognize are the
  // ones the compiler would honor, which is exactly the set we must gate.
  final unit = parseString(content: code, throwIfDiagnostics: false).unit;
  final disallowed = <String>[];
  for (final directive in unit.directives) {
    if (directive is! NamespaceDirective) continue; // import or export only
    for (final uri in _urisOf(directive)) {
      if (uri == null || _isAllowed(uri) || disallowed.contains(uri)) continue;
      disallowed.add(uri);
    }
  }
  return disallowed;
}

/// The deepest bracket nesting an authored composition should ever reach.
/// Anything deeper is a parser-DoS attempt, not a real widget tree.
const int _maxNestingDepth = 1024;

/// The pseudo-entry [disallowedImports] returns for over-nested source, so the
/// caller rejects it exactly as it rejects a disallowed import.
const String _tooDeeplyNested = 'the source nests too deeply to analyze safely';

/// Whether [code] nests `(`/`[`/`{` past [_maxNestingDepth] — a linear scan run
/// before [parseString] so a bracket bomb cannot stall the isolate. It counts
/// brackets in strings and comments too, which only makes it stricter; a real
/// composition stays far below the limit.
bool _nestsPastLimit(String code) {
  var depth = 0;
  for (var i = 0; i < code.length; i++) {
    final c = code.codeUnitAt(i);
    if (c == 0x28 || c == 0x5B || c == 0x7B) {
      if (++depth > _maxNestingDepth) return true;
    } else if (c == 0x29 || c == 0x5D || c == 0x7D) {
      if (depth > 0) depth--;
    }
  }
  return false;
}

/// The default URI plus every conditional-configuration URI a directive names.
/// A `null` URI (an interpolated string, which cannot be a real import target)
/// is yielded and skipped by the caller.
Iterable<String?> _urisOf(NamespaceDirective directive) sync* {
  yield directive.uri.stringValue;
  for (final configuration in directive.configurations) {
    yield configuration.uri.stringValue;
  }
}

bool _isAllowed(String uri) {
  if (_allowedExact.contains(uri)) return true;
  for (final prefix in _allowedPrefixes) {
    // A prefix grants the package's public libraries only. Its `src/` tree is
    // private and re-exposes dart:io internals, so it stays out of reach even
    // though it lives under the same package.
    if (uri.startsWith(prefix) && !uri.startsWith('$prefix$_privateSubtree')) {
      return true;
    }
  }
  return false;
}

/// Thrown when a snippet imports a library outside the Playground allowlist.
final class CodeImportException implements Exception {
  /// Creates the exception from the [disallowed] libraries it found.
  CodeImportException(this.disallowed);

  /// The rejected libraries, in source order.
  final List<String> disallowed;

  /// A client-safe message naming every rejected library.
  String get message =>
      'Disallowed import(s): ${disallowed.join(', ')}. A Playground snippet may '
      'only import package:fluvie, package:flutter, dart:math, and dart:ui.';

  @override
  String toString() => 'CodeImportException: $message';
}
