@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:fluvie_presenter/src/sidebar/slide_preview_frame.dart';
import 'package:slides/deck/deck_registry.dart';

/// One representative slide per tutorial deck, settled at its final step —
/// the pin that keeps the tutorial from rotting.
Widget _slide(String deckId, {int slide = 0}) {
  final video = deckById(deckId)!.build();
  final plans = compileSlidePlans(video);
  return SizedBox(
    width: 480,
    height: 270,
    child: SlidePreviewFrame(video: video, plan: plans[slide]),
  );
}

Future<void> main() async {
  await goldenTest(
    'each tutorial deck presents its representative slide',
    fileName: 'tutorial_decks',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        GoldenTestScenario(name: 'plain slides', child: _slide('welcome')),
        GoldenTestScenario(name: 'builds with Stop', child: _slide('builds')),
        GoldenTestScenario(name: 'speaker notes', child: _slide('notes')),
        GoldenTestScenario(name: 'media-heavy', child: _slide('media')),
        GoldenTestScenario(name: 'the full talk', child: _slide('talk', slide: 1)),
      ],
    ),
  );
}
