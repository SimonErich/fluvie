import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:fluvie_presenter/src/sidebar/slide_preview_frame.dart';
import 'package:fluvie_presenter/src/speaker/speaker_next_preview.dart';
import 'package:fluvie_presenter/src/speaker/speaker_view.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

Video _deck() => Video(
  width: 320,
  height: 180,
  scenes: const [
    Scene(
      duration: Time.seconds(2),
      children: [
        SpeakerNotes(text: 'open with the story', highlights: ['one line fix']),
        Text('one', style: TextStyle(fontSize: 16)),
        Stop(children: [SizedBox(width: 4, height: 4)]),
      ],
    ),
    Scene(duration: Time.seconds(2)),
  ],
);

(ProviderContainer, Widget) _speaker(Video video) {
  final plans = compileSlidePlans(video);
  final container = ProviderContainer(
    overrides: [
      slidePlansProvider.overrideWithValue(plans),
      slideNotesProvider.overrideWithValue(compileNotes(video, plans)),
    ],
  );
  addTearDown(container.dispose);
  final widget = UncontrolledProviderScope(
    container: container,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(960, 640)),
        child: OiThemeScope(
          data: OiThemeData.dark(),
          child: SpeakerView(video: video),
        ),
      ),
    ),
  );
  return (container, widget);
}

void main() {
  testWidgets('shows the notes, the indicators, and the ticking clock', (tester) async {
    final (_, widget) = _speaker(_deck());
    await tester.pumpWidget(widget);
    await tester.pump();
    expect(find.text('open with the story'), findsOneWidget);
    expect(find.text('•  one line fix'), findsOneWidget);
    expect(find.text('Slide 1 / 2'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 65));
    expect(find.text('01:05'), findsOneWidget);
  });

  testWidgets('the next preview follows navigation and ends honestly', (tester) async {
    final (container, widget) = _speaker(_deck());
    await tester.pumpWidget(widget);
    await tester.pump();
    // At (0,0) the next input reveals step 1 of slide 0.
    var frame = tester.widget<SlidePreviewFrame>(find.byType(SlidePreviewFrame));
    expect(frame.plan.sceneIndex, 0);
    expect(frame.step, 1);

    container.read(presentationControllerProvider.notifier).next();
    await tester.pump();
    // At (0,1) the next input lands on slide 1, step 0.
    frame = tester.widget<SlidePreviewFrame>(find.byType(SlidePreviewFrame));
    expect(frame.plan.sceneIndex, 1);
    expect(frame.step, 0);

    container.read(presentationControllerProvider.notifier).next();
    await tester.pump();
    expect(find.byType(SlidePreviewFrame), findsNothing);
    expect(find.text('End of deck'), findsOneWidget);
    expect(find.byType(SpeakerNextPreview), findsOneWidget);
  });
}
