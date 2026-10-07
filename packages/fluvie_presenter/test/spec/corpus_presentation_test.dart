import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

/// The presenter's half of the conformance corpus: every document fluvie
/// accepts must also present. Each fixture builds through [deckFromSpec],
/// compiles slide plans and notes, and validates clean — so the spec codecs
/// and the presentation compiler can never drift apart.
void main() {
  final corpus =
      Directory('../fluvie/test/serialization/corpus')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.fluvie.json'))
          .toList(growable: false)
        ..sort((a, b) => a.path.compareTo(b.path));

  test('the corpus is visible from the presenter and holds the maximal fixture', () {
    expect(corpus, isNotEmpty);
    expect(
      corpus.map((file) => file.uri.pathSegments.last),
      contains('maximal.fluvie.json'),
      reason:
          'The corpus sweep closes with one maximal document exercising the '
          'union surface; add test/serialization/corpus/maximal.fluvie.json.',
    );
  });

  for (final file in corpus) {
    final name = file.uri.pathSegments.last;

    group(name, () {
      late VideoSpec spec;

      setUp(() {
        spec = VideoSpec.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, Object?>);
      });

      test('presents: deckFromSpec, plans, and notes all compile', () {
        final deck = deckFromSpec(spec);
        final plans = compileSlidePlans(deck);
        expect(plans, hasLength(spec.scenes.length));
        for (var s = 0; s < spec.scenes.length; s++) {
          expect(
            plans[s].stepCount,
            spec.scenes[s].steps.length + 1,
            reason: '$name scene $s: one slide step per spec step plus the base',
          );
        }
        final notes = compileNotes(deck, plans);
        expect(notes, hasLength(plans.length));
      });

      test('validates clean', () {
        expect(validateStepPlan(spec), isEmpty);
      });
    });
  }
}
