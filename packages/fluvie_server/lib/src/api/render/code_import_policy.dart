/// The Playground import allowlist: which libraries a submitted `Video build()`
/// snippet may `import`/`export`. Everything else is rejected before the code is
/// ever compiled or run, because the snippet executes as untrusted code inside a
/// `flutter test` capture.
///
/// Allowed:
/// - any `package:fluvie/...` path (the public API and its `src/`),
/// - any `package:flutter/...` library (the UI framework: `material`, `widgets`,
///   `painting`, `animation`, ...), none of which can touch the filesystem or
///   network — a composition is a widget tree,
/// - `dart:math` and `dart:ui`.
///
/// Rejected (a non-exhaustive list of the dangerous ones): `dart:io`, `dart:ffi`,
/// `dart:isolate`, `dart:mirrors`, any `http`/network package, and any other
/// third-party package — none of which a pure composition needs.
library;

/// Libraries a snippet may import or export, matched exactly.
const Set<String> _allowedExact = {'dart:math', 'dart:ui'};

/// Library prefixes a snippet may import or export (any sub-path is allowed).
/// The flutter framework is pure UI — it exposes no filesystem or socket APIs.
const List<String> _allowedPrefixes = ['package:fluvie/', 'package:flutter/'];

// A whole import/export directive from the start of a (possibly indented) line
// up to its terminating semicolon. Anchored to a line start so an import-like
// string inside a body or a trailing comment is not mistaken for a directive.
// Spans lines because a directive may wrap, and captures the whole directive so
// every URI it names is checked (see [disallowedImports]).
final RegExp _directive = RegExp(
  r'''^[ \t]*(?:import|export)\b[^;]*;''',
  multiLine: true,
);

// A quoted URI inside a directive.
final RegExp _uri = RegExp(r'''['"]([^'"]+)['"]''');

// A whole-line `//` comment, removed before scanning so a commented-out import
// is ignored.
final RegExp _lineComment = RegExp(r'^[ \t]*//.*$', multiLine: true);

/// The libraries [code] imports or exports that are not on the allowlist, in
/// source order with duplicates removed. Empty means the snippet's imports are
/// safe to compile.
///
/// Every URI a directive names is checked, so a conditional import
/// (`import '...' if (dart.library.io) 'dart:io';`) cannot smuggle a disallowed
/// library past the allowlist through its second URI.
List<String> disallowedImports(String code) {
  final scrubbed = code.replaceAll(_lineComment, '');
  final disallowed = <String>[];
  for (final directive in _directive.allMatches(scrubbed)) {
    for (final match in _uri.allMatches(directive.group(0)!)) {
      final uri = match.group(1)!;
      if (_isAllowed(uri) || disallowed.contains(uri)) continue;
      disallowed.add(uri);
    }
  }
  return disallowed;
}

bool _isAllowed(String uri) {
  if (_allowedExact.contains(uri)) return true;
  for (final prefix in _allowedPrefixes) {
    if (uri.startsWith(prefix)) return true;
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
