import 'dart:io';

import 'package:test/test.dart';

/// The example capture harnesses that must stay byte-identical outside their
/// delimited `--- compositions ---` blocks. They intentionally model the
/// self-contained harness `fluvie init` scaffolds, so they may not share code;
/// this pin is what keeps the copies from drifting apart.
const _harnesses = [
  'examples/cli_quickstart/test/render/capture_harness_test.dart',
  'examples/desktop_studio/test/render/capture_harness_test.dart',
];

const _blockStart = '// --- compositions ---';
const _blockEnd = '// --- end compositions ---';

/// Returns [source] with every `--- compositions ---` block removed. Only a
/// line that is exactly the marker comment delimits a block, so prose mentions
/// of the marker (the harness header) pass through as shared body.
String _stripCompositionBlocks(String path, String source) {
  final lines = source.split('\n');
  final kept = <String>[];
  var inBlock = false;
  for (final line in lines) {
    if (line.trim() == _blockStart) {
      expect(inBlock, isFalse, reason: '$path nests $_blockStart markers');
      inBlock = true;
      continue;
    }
    if (line.trim() == _blockEnd) {
      expect(inBlock, isTrue, reason: '$path has $_blockEnd without a start');
      inBlock = false;
      continue;
    }
    if (!inBlock) kept.add(line);
  }
  expect(inBlock, isFalse, reason: '$path leaves a $_blockStart block open');
  return kept.join('\n');
}

void main() {
  test('the example capture harnesses are identical outside their registries', () {
    final stripped = <String, String>{
      for (final path in _harnesses)
        path: _stripCompositionBlocks(path, File(path).readAsStringSync()),
    };
    final canonical = stripped[_harnesses.first]!;
    for (final path in _harnesses.skip(1)) {
      expect(
        stripped[path],
        canonical,
        reason:
            '$path drifted from ${_harnesses.first}. Edit the shared body in '
            'both files (only the --- compositions --- blocks may differ).',
      );
    }
  });
}
