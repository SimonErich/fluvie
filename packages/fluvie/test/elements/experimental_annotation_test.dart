// The snapshot widgets ship with their live headless-Chrome transport disabled
// in 1.0, so each carries `@experimental` (the Phase 12 deferral, closed in
// Epic 15.1). This test reads the source of the three classes and asserts the
// annotation sits directly above each declaration, so the contract cannot
// silently regress.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('@experimental snapshot widgets', () {
    const targets = <String, String>{
      'lib/src/elements/mermaid/mermaid.dart': 'final class Mermaid',
      'lib/src/elements/webview/webview.dart': 'final class WebView',
      'lib/src/elements/webview/html.dart': 'final class Html',
    };

    for (final entry in targets.entries) {
      final path = entry.key;
      final declaration = entry.value;
      test('$declaration is annotated @experimental', () {
        final source = File(path).readAsStringSync();
        final declIndex = source.indexOf(declaration);
        expect(declIndex, greaterThan(-1), reason: '$declaration missing');
        final before = source.substring(0, declIndex).trimRight();
        final lastLine = before.split('\n').last.trim();
        expect(
          lastLine,
          '@experimental',
          reason: '$declaration must be preceded by @experimental',
        );
        expect(
          source,
          contains("import 'package:meta/meta.dart';"),
          reason: '$path must import meta for @experimental',
        );
      });
    }
  });
}
