// The Phase 15 doc snippets compile and build (WI-39, WI-37): the
// animating-elements, performance, and migration pages pull these via
// code-excerpt markers, so a failing build here means a doc would ship dead
// code.

import 'package:flutter/widgets.dart' show Widget;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/snippets/migration_snippets.dart';
import 'package:fluvie_example/snippets/phase_15_snippets.dart';

void main() {
  test('the animate snippets build their widgets', () {
    expect(animateBasics(), isA<Widget>());
    expect(composeEnterExit(), isA<Widget>());
    expect(shapeTiming(), isA<Widget>());
    expect(springTiming(), isA<Widget>());
    expect(triggerVocabulary(Anchor('intro')), isA<Widget>());
    expect(staggerChildren(), isA<Widget>());
    expect(sceneDefaults(), isA<Scene>());
    expect(customKeyframe(), isA<Widget>());
    expect(stableAnimationList(), isA<Widget>());
  });

  test('the preset and repeat menus list animations', () {
    expect(presetMenu(), hasLength(6));
    expect(repeatMenu(), hasLength(2));
    expect(presetMenu(), everyElement(isA<Animation>()));
  });

  test('the performance snippets reuse one media declaration', () {
    final media = reuseMedia('https://example.com/logo.png');
    expect(media, hasLength(2));
    expect(identical(media[0], media[1]), isTrue);
  });

  test('the migration snippets build their new-form replacements', () {
    expect(migrateAnimate(), isA<Widget>());
    expect(migrateStagger(), isA<Widget>());
    expect(migrateLayout(), isA<Widget>());
    expect(migrateEffects(), isA<Widget>());
    expect(migrateImage('https://example.com/photo.jpg'), isA<Widget>());
    expect(migrateLoop(), isA<Widget>());
    expect(migrateClip(Uri.parse('https://example.com/b-roll.mp4')), isA<Widget>());
    expect(migrateAudio('assets/music.wav'), hasLength(1));
    expect(migrateExport(), isA<Export>());
  });
}
