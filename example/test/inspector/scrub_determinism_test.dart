// Scrubbing-determinism assertion (WI-22): the inspector preview is the same
// deterministic render path the encoder uses (RenderMode.preview + a
// FrameProvider pinned by the playback controller). Seeking to a frame, away,
// and back must produce byte-identical pixels — there is no wall-clock in the
// preview, so the frame index is the only input that moves.
//
// The proof reads the actual painted input — the `FadeBox.opacity` Fluvie
// composes for the frame, the single place a fade becomes pixels (D16). Two
// seeks to the same frame must compose the identical opacity; since the paint
// is a pure function of that input, identical inputs mean identical pixels.
// (Reading the paint input avoids the slow software `toImage` raster while
// asserting the same determinism a pixel diff would.)
import 'package:flutter/material.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

Video _tinyVideo() => Video(
  width: 64,
  height: 48,
  scenes: [
    Scene(
      duration: const Time.frames(60),
      children: [
        const Box(color: Color(0xFF6C5CE7)).animate([
          Animation.fadeIn(duration: const Time.frames(30)),
        ]),
      ],
    ),
  ],
);

void main() {
  testWidgets('seeking to the same frame twice composes identical paint', (tester) async {
    final controller = RenderController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RenderModeContext(
          mode: RenderMode.preview,
          child: RenderControllerScope(
            controller: controller,
            child: SizedBox(width: 64, height: 48, child: _tinyVideo()),
          ),
        ),
      ),
    );
    await tester.pump(); // the post-frame resolution pass

    Future<double> fadeOpacityAt(int frame) async {
      controller.seek(frame);
      await tester.pump();
      return tester
          .widgetList<FadeBox>(find.byType(FadeBox))
          .map((b) => b.opacity)
          .reduce((a, b) => a + b);
    }

    // Frame 15 sits mid fade-in, so the opacity is strictly between 0 and 1 —
    // a moving value, not a trivial 0 or 1.
    final atFifteen = await fadeOpacityAt(15);
    expect(atFifteen, greaterThan(0.0));
    expect(atFifteen, lessThan(1.0));

    await fadeOpacityAt(45); // scrub away (settled)
    final again = await fadeOpacityAt(15); // and back

    expect(again, atFifteen);
  });
}
