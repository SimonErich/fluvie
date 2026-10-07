// The effect browser's catalog: every kind the spec knows, grouped for the
// browser, found by a search that reads names and blurbs.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show EffectSpecKind;
import 'package:fluvie_editor/fluvie_editor.dart';

void main() {
  group('the catalog', () {
    test('carries every effect kind the spec knows, exactly once', () {
      expect(
        effectCatalog.map((entry) => entry.kind).toSet(),
        EffectSpecKind.values.toSet(),
      );
      expect(effectCatalog.length, EffectSpecKind.values.length);
    });

    test('every entry names its group and says what it does', () {
      for (final entry in effectCatalog) {
        expect(entry.group, isNotEmpty, reason: entry.kind.name);
        expect(entry.blurb, isNotEmpty, reason: entry.kind.name);
      }
    });

    test('the default document form is just the kind, on its own defaults', () {
      final entry = effectCatalog.firstWhere((e) => e.kind == EffectSpecKind.grain);

      expect(entry.json(), {'kind': 'grain'});
    });
  });

  group('searching it', () {
    test('an empty query is the whole catalog in order', () {
      expect(searchEffectCatalog(''), effectCatalog);
    });

    test('finds by name, case-insensitively', () {
      expect(
        searchEffectCatalog('VIGN').map((entry) => entry.kind),
        [EffectSpecKind.vignette],
      );
    });

    test('finds by what the blurb says, not only the name', () {
      // "film" appears in the grain blurb; an author searching a feeling
      // still lands on the effect.
      expect(
        searchEffectCatalog('film').map((entry) => entry.kind),
        contains(EffectSpecKind.grain),
      );
    });

    test('a query nothing matches is empty, not an error', () {
      expect(searchEffectCatalog('zzz'), isEmpty);
    });
  });
}
