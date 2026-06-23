import 'dart:io';

import 'package:fluvie_cli/src/templates/starter_composition_template.dart';
import 'package:test/test.dart';

/// The starter the CLI scaffolds must stay in step with the compiled,
/// docs-excerpted source of truth in the example app, so the docs and the
/// generated file never drift.
void main() {
  test('the CLI starter template matches the example docregions', () {
    final example = File('../../example/lib/starter/starter_video.dart');
    if (!example.existsSync()) {
      markTestSkipped('example/lib/starter/starter_video.dart not found (standalone checkout)');
      return;
    }
    final content = example.readAsStringSync();
    final source = starterCompositionSource();

    for (final region in ['imports', 'video']) {
      final body = _docregion(content, region);
      expect(
        _normalize(source),
        contains(_normalize(body)),
        reason: 'starterCompositionSource() drifted from the "$region" docregion',
      );
    }
  });
}

String _docregion(String content, String name) {
  final lines = content.split('\n');
  final start = lines.indexOf('// #docregion $name');
  final end = lines.indexOf('// #enddocregion $name');
  if (start < 0 || end < 0 || end <= start) {
    throw StateError('Could not find docregion "$name"');
  }
  return lines.sublist(start + 1, end).join('\n');
}

String _normalize(String s) => s.split('\n').map((l) => l.trimRight()).join('\n').trim();
