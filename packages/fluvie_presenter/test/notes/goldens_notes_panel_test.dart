@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:fluvie_presenter/src/notes/notes_panel.dart';
import 'package:fluvie_presenter/src/shell/ui_state.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

Widget _panel(SlideNotes notes) {
  final container = ProviderContainer(
    overrides: [
      slidePlansProvider.overrideWithValue(const [
        SlidePlan(
          sceneIndex: 0,
          steps: [SlideStep(index: 0, stops: [], entranceFrames: 0)],
        ),
      ]),
      slideNotesProvider.overrideWithValue([
        [notes],
      ]),
      notesVisibleProvider.overrideWith(() => UiToggle(initiallyVisible: true)),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: OiThemeScope(
      data: OiThemeData.dark(),
      child: const SizedBox(width: 520, child: NotesPanel()),
    ),
  );
}

Future<void> main() async {
  await goldenTest(
    'the notes panel shows the prose and the highlight bullets',
    fileName: 'notes_panel',
    builder: () => GoldenTestGroup(
      children: [
        GoldenTestScenario(
          name: 'text and highlights',
          child: _panel(
            const SlideNotes(
              text:
                  'Open with the outage story: the 3am page, fourteen services '
                  'down, and the one-line fix nobody wanted to ship.',
              highlights: ['3am page', '14 services down', 'one line fix'],
            ),
          ),
        ),
        GoldenTestScenario(
          name: 'no notes here',
          child: _panel(const SlideNotes()),
        ),
      ],
    ),
  );
}
