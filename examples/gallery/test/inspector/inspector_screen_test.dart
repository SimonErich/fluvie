// Inspector shell widget tests: the screen under a real ProviderScope. The
// centre stage shows the cached/rendered video; the Motions tab (behind the
// default Code tab) shows the resolved schedule for the selected lesson.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/inspector/inspector_screen.dart';
import 'package:fluvie_example/playground/ai_author_backend.dart';
import 'package:fluvie_example/playground/playground_view_model.dart';

import '../playground/fake_ai_author_backend.dart';
import '../playground/fake_playground_backend.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The right pane defaults to the Playground (Code tab); fake backends
          // keep validation and AI generation deterministic and offline.
          playgroundBackendProvider.overrideWithValue(FakePlaygroundBackend()),
          aiAuthorBackendProvider.overrideWithValue(FakeAiAuthorBackend()),
        ],
        child: const MaterialApp(home: InspectorScreen()),
      ),
    );
    // The post-frame pass resolves the composition; the pump applies it.
    await tester.pump();
  }

  int previewedFrame(WidgetTester tester) =>
      tester.widget<FrameProvider>(find.byType(FrameProvider)).frame;

  testWidgets('the Motions tab shows the resolved schedule (WI-22)', (tester) async {
    await pumpScreen(tester);
    // The inspector panel lives behind the Motions tab (Code is the default).
    await tester.tap(find.text('Motions'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // finish the tab swap

    expect(find.text('Resolved schedule'), findsOneWidget);
    expect(find.textContaining('120 frames @ 30 fps'), findsOneWidget);
    expect(find.text('Motions'), findsWidgets); // the tab label and the panel header
    expect(find.textContaining('s0e0'), findsWidgets);
  });

  testWidgets('selecting a lesson updates the resolved schedule', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Timing and triggers'));
    await tester.pump(); // rebuild with the new lesson
    await tester.pump(); // its post-frame resolution pass

    expect(previewedFrame(tester), 0); // the hidden preview opens at the start

    // The frame-count readout lives in the inspector panel, behind the Motions tab.
    await tester.tap(find.text('Motions'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('300 frames @ 30 fps'), findsOneWidget);
  });

  testWidgets('selecting AI Assistant shows the prompt panel and the placeholder', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('AI Assistant'));
    await tester.pump();

    expect(find.text('Generate a video with AI'), findsOneWidget);
    expect(find.text('Your AI video will appear here'), findsOneWidget);
  });
}
