/// The Playground import allowlist: which libraries a submitted `Video build()`
/// snippet may `import`/`export`. Everything else is rejected before the code is
/// ever compiled or run, because the snippet executes as untrusted code inside a
/// `flutter test` capture.
///
/// Allowed:
/// - any `package:fluvie/...` path (the public API and its `src/`),
/// - `package:flutter/painting.dart` and `package:flutter/animation.dart` — the
///   value-type libraries (`Color`, `Alignment`, `Curve`, ...) fluvie re-exports,
/// - `dart:math` and `dart:ui`.
///
/// Rejected (a non-exhaustive list of the dangerous ones): `dart:io`, `dart:ffi`,
/// `dart:isolate`, `dart:mirrors`, any `http`/network package, and any other
/// third-party package — none of which a pure composition needs.
library;

/// Libraries a snippet may import or export, matched exactly.
const Set<String> _allowedExact = {
  'dart:math',
  'dart:ui',
  'package:flutter/painting.dart',
  'package:flutter/animation.dart',
};

/// Library prefixes a snippet may import or export (any sub-path is allowed).
const List<String> _allowedPrefixes = ['package:fluvie/'];

// A directive at the start of a (possibly indented) line, capturing its URI.
// Anchored to a line start so an import-like string inside a body or a trailing
// comment is not mistaken for a directive.
final RegExp _directive = RegExp(
  r'''^[ \t]*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

// A whole-line `//` comment, removed before scanning so a commented-out import
// is ignored.
final RegExp _lineComment = RegExp(r'^[ \t]*//.*$', multiLine: true);

/// The libraries [code] imports or exports that are not on the allowlist, in
/// source order with duplicates removed. Empty means the snippet's imports are
/// safe to compile.
List<String> disallowedImports(String code) {
  final scrubbed = code.replaceAll(_lineComment, '');
  final disallowed = <String>[];
  for (final match in _directive.allMatches(scrubbed)) {
    final uri = match.group(1)!;
    if (_isAllowed(uri) || disallowed.contains(uri)) continue;
    disallowed.add(uri);
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
      'only import package:fluvie, package:flutter/painting.dart, '
      'package:flutter/animation.dart, dart:math, and dart:ui.';

  @override
  String toString() => 'CodeImportException: $message';
}
