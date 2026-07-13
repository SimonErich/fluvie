@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:fluvie_presenter/src/shell/presenter_shell.dart';

Video _deck() => Video(
  width: 320,
  height: 180,
  scenes: [
    Scene(
      duration: const Time.seconds(4),
      background: Background.color(const Color(0xFF1B2838)),
      children: [
        const Text(
          'the stage',
          style: TextStyle(color: Color(0xFFF2F2F7), fontSize: 28),
        ).animate([Animation.fadeIn(duration: const Time.seconds(0.5))]),
      ],
    ),
    const Scene(duration: Time.seconds(2)),
  ],
);

/// The shell in a viewport, deck held at frame 45 (entrances settled).
Widget _stage(Size viewport) {
  final video = _deck();
  final container = ProviderContainer(
    overrides: [slidePlansProvider.overrideWithValue(compileSlidePlans(video))],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: SizedBox(
      width: viewport.width,
      height: viewport.height,
      child: PresenterShell(
        video: video,
        clockFactory: (fps) => LivePlaybackController(fps: fps)..hold(45),
      ),
    ),
  );
}

Future<void> main() async {
  await goldenTest(
    'the stage letterboxes the slide into any viewport, HUD on top',
    fileName: 'presenter_stage',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        GoldenTestScenario(name: 'wide viewport', child: _stage(const Size(360, 140))),
        GoldenTestScenario(name: 'square viewport', child: _stage(const Size(240, 240))),
      ],
    ),
  );
}
