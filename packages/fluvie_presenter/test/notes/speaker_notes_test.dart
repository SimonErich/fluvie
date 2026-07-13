import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

void main() {
  testWidgets('renders nothing on stage and takes no space', (tester) async {
    final video = Video(
      width: 320,
      height: 180,
      scenes: const [
        Scene(
          duration: Time.seconds(2),
          children: [
            SpeakerNotes(text: 'never on stage', highlights: ['secret']),
            Text('visible', style: TextStyle(fontSize: 16)),
          ],
        ),
      ],
    );
    final controller = LivePlaybackController(fps: 30);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: LivePlayer(controller: controller, child: video),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('visible'), findsOneWidget);
    expect(find.text('never on stage'), findsNothing);
    expect(find.text('secret'), findsNothing);
    expect(tester.getSize(find.byType(SpeakerNotes)), Size.zero);
  });

  test('carries its authored fields', () {
    const notes = SpeakerNotes(text: 'the why', highlights: ['a', 'b']);
    expect(notes.text, 'the why');
    expect(notes.highlights, ['a', 'b']);
    expect(const SpeakerNotes().text, isNull);
    expect(const SpeakerNotes().highlights, isEmpty);
  });

  test('the walkers see it inside scenes and stops', () {
    const inScene = SpeakerNotes(text: 'scene');
    const inStop = SpeakerNotes(text: 'step');
    const stop = Stop(children: [inStop]);
    final seen = <SpeakerNotes>[];
    walkSceneTree(
      const [
        Scene(duration: Time.seconds(1), children: [inScene, stop]),
      ],
      (widget) {
        if (widget is SpeakerNotes) seen.add(widget);
      },
    );
    expect(seen, [same(inScene), same(inStop)]);
  });
}
