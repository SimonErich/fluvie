import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
// The render pre-pass sfx resolver, reached off the authoring barrel like the
// render shell, so the test can resolve one-shot sfx the way the audio mix does.
import 'package:fluvie/src/audio/encoding/sfx_trigger_resolver.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:kitten_kit/kitten_kit.dart';

// Mounting each composition and seeking through frames resolves its animation
// timing plan, so an invalid Trigger (for example a `Trigger.previous` with no
// preceding animation) fails here, not only at render time.
void main() {
  final cases = <(String, Video)>[
    ('kittenPromo', kittenPromo(headline: 'Kitten Mitten', tagline: 'Cozy paws')),
    ('kittenPromo (no music, no tagline)', kittenPromo(headline: 'Solo', withMusic: false)),
    ('birthdayCard', birthdayCard(catName: 'Mittens')),
    ('memePromo', memePromo(topText: 'when', bottomText: 'naptime')),
  ];

  for (final (name, video) in cases) {
    testWidgets('$name resolves its timeline and builds without error', (tester) async {
      final controller = RenderController();
      await tester.pumpWidget(
        RenderControllerScope(
          controller: controller,
          child: Directionality(textDirection: TextDirection.ltr, child: video),
        ),
      );

      for (final frame in [0, video.totalFrames ~/ 2, video.totalFrames - 1]) {
        controller.seek(frame);
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
    });
  }

  // A one-shot Audio.sfx resolves at the audio-mix stage, not during a preview
  // seek, so the mount test above cannot catch an sfx placed at a scene- or
  // element-scoped trigger. Resolve each the way stageAudioMix does to prove the
  // effects are composition-scoped (Trigger.at or null), not render-time bombs.
  for (final (name, video) in cases) {
    test('$name one-shot sfx resolve at the composition scope', () {
      final scope = TimeScopeData(
        fps: video.fps,
        startFrame: 0,
        durationFrames: video.totalFrames,
      );
      for (final track in video.audio.where((track) => track.isSfx)) {
        expect(() => resolveSfxFrame(track.at, scope), returnsNormally, reason: name);
      }
    });
  }
}
