@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:fluvie_presenter/src/speaker/speaker_view.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

Video _deck() => Video(
  width: 320,
  height: 180,
  scenes: [
    Scene(
      duration: const Time.seconds(4),
      background: Background.color(const Color(0xFF1B2838)),
      children: const [
        SpeakerNotes(
          text:
              'Open with the outage story: the 3am page, fourteen services '
              'down, and the one-line fix nobody wanted to ship.',
          highlights: ['3am page', '14 services down', 'one line fix'],
        ),
        Text('incident review', style: TextStyle(color: Color(0xFFF2F2F7), fontSize: 24)),
        Stop(
          children: [SizedBox(width: 60, height: 20, child: ColoredBox(color: Color(0xFF6C5CE7)))],
        ),
      ],
    ),
    const Scene(duration: Time.seconds(2)),
  ],
);

Widget _speaker() {
  final video = _deck();
  final plans = compileSlidePlans(video);
  final container = ProviderContainer(
    overrides: [
      slidePlansProvider.overrideWithValue(plans),
      slideNotesProvider.overrideWithValue(compileNotes(video, plans)),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: OiThemeScope(
      data: OiThemeData.dark(),
      child: SizedBox(
        width: 640,
        height: 400,
        child: SpeakerView(video: video),
      ),
    ),
  );
}

Future<void> main() async {
  await goldenTest(
    'the speaker view: next state, notes, highlights, and the clock',
    fileName: 'speaker_view',
    builder: () => GoldenTestScenario(name: 'speaker', child: _speaker()),
  );
}
