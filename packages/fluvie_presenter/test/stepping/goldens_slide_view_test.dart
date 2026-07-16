@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

/// A representative slide: a title (step 0), a revealed card (step 1), and
/// a footer badge (step 2), on solid colors so every variant is pinned.
Video _deck() => Video(
  width: 320,
  height: 180,
  scenes: [
    Scene(
      duration: const Time.seconds(4),
      background: Background.color(const Color(0xFF14141C)),
      children: [
        Align(
          alignment: const Alignment(0, -0.6),
          child: const Text(
            'stepping',
            style: TextStyle(color: Color(0xFFF2F2F7), fontSize: 24),
          ).animate([Animation.fadeIn(duration: const Time.seconds(0.5))]),
        ),
        Stop.single(
          child: const SizedBox(
            width: 120,
            height: 40,
            child: ColoredBox(color: Color(0xFF6C5CE7)),
          ).animate([Animation.fadeIn(duration: const Time.seconds(0.5))]),
        ),
        Stop.single(
          child: Align(
            alignment: const Alignment(0, 0.7),
            child: const SizedBox(
              width: 60,
              height: 16,
              child: ColoredBox(color: Color(0xFF55EFC4)),
            ).animate([Animation.fadeIn(duration: const Time.seconds(0.5))]),
          ),
        ),
      ],
    ),
  ],
);

/// A slide held at frame 45 (all entrances settled), navigated to [step].
Widget _heldAt(int step) {
  final video = _deck();
  final container = ProviderContainer(
    overrides: [slidePlansProvider.overrideWithValue(compileSlidePlans(video))],
  );
  addTearDown(container.dispose);
  if (step > 0) {
    container.read(presentationControllerProvider.notifier).jumpToStep(0, step);
  }
  return UncontrolledProviderScope(
    container: container,
    child: SizedBox(
      width: 320,
      height: 180,
      child: SlideView(
        video: video,
        clockFactory: (fps) => LivePlaybackController(fps: fps)..hold(45),
      ),
    ),
  );
}

Future<void> main() async {
  await goldenTest(
    'a slide renders each step held at its settled state',
    fileName: 'slide_view_steps',
    builder: () => GoldenTestGroup(
      columns: 3,
      children: [
        GoldenTestScenario(name: 'step 0', child: _heldAt(0)),
        GoldenTestScenario(name: 'step 1', child: _heldAt(1)),
        GoldenTestScenario(name: 'final step', child: _heldAt(2)),
      ],
    ),
  );
}
