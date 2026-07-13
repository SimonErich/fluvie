import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

Video _video() => Video(
  width: 320,
  height: 180,
  scenes: [
    Scene(
      duration: const Time.seconds(2),
      children: [
        const Text(
          'hello',
          style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 40),
        ).animate([Animation.fadeIn()]),
      ],
    ),
  ],
);

void main() {
  testWidgets('presents a one-scene video live', (tester) async {
    await tester.pumpWidget(FluvieSlides(_video()));
    expect(find.byType(LiveScenePlayer), findsOneWidget);
    expect(find.byType(Video), findsOneWidget);
    // The composition resolves post-frame, then plays: the content is live.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('accepts the minimal config surface', (tester) async {
    await tester.pumpWidget(
      FluvieSlides(_video(), showSidebar: true, showNotes: true, startFullscreen: true),
    );
    expect(find.byType(FluvieSlides), findsOneWidget);
  });
}
