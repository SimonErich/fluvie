import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
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
}
