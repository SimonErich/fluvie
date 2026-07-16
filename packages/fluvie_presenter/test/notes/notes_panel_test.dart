import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:fluvie_presenter/src/shell/presenter_shell.dart';
import 'package:fluvie_presenter/src/shell/ui_state.dart';

Video _deck() => Video(
  width: 320,
  height: 180,
  scenes: const [
    Scene(
      duration: Time.seconds(2),
      children: [
        SpeakerNotes(text: 'open with the story', highlights: ['one line fix']),
        Stop(
          children: [
            SizedBox(width: 4, height: 4),
            SpeakerNotes(text: 'now the numbers'),
          ],
        ),
      ],
    ),
    Scene(duration: Time.seconds(2)),
  ],
);

(ProviderContainer, Widget) _present(Video video, {bool notesOpen = false}) {
  final plans = compileSlidePlans(video);
  final container = ProviderContainer(
    overrides: [
      slidePlansProvider.overrideWithValue(plans),
      slideNotesProvider.overrideWithValue(compileNotes(video, plans)),
      if (notesOpen) notesVisibleProvider.overrideWith(() => UiToggle(initiallyVisible: true)),
    ],
  );
  addTearDown(container.dispose);
  final widget = UncontrolledProviderScope(
    container: container,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: PresenterShell(video: video),
    ),
  );
  return (container, widget);
}

void main() {
  testWidgets('hidden by default, N opens it onto the current notes', (tester) async {
    final (_, widget) = _present(_deck());
    await tester.pumpWidget(widget);
    await tester.pump();
    expect(find.text('open with the story'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.pump();
    expect(find.text('open with the story'), findsOneWidget);
    expect(find.text('•  one line fix'), findsOneWidget);
  });

  testWidgets('follows navigation: step and slide changes swap the notes', (tester) async {
    final (container, widget) = _present(_deck(), notesOpen: true);
    await tester.pumpWidget(widget);
    await tester.pump();
    expect(find.text('open with the story'), findsOneWidget);

    container.read(presentationControllerProvider.notifier).next();
    await tester.pump();
    // The step note replaces the text; the scene highlight stays.
    expect(find.text('now the numbers'), findsOneWidget);
    expect(find.text('open with the story'), findsNothing);
    expect(find.text('•  one line fix'), findsOneWidget);

    container.read(presentationControllerProvider.notifier).jumpToSlide(1);
    await tester.pump();
    expect(find.text('now the numbers'), findsNothing);
    expect(find.text('No notes for this slide.'), findsOneWidget);
  });

  testWidgets('the showNotes flag opens the panel from the start', (tester) async {
    await tester.pumpWidget(FluvieSlides(_deck(), showNotes: true));
    await tester.pump();
    expect(find.text('open with the story'), findsOneWidget);
  });
}
