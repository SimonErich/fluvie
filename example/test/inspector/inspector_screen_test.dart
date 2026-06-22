// Inspector shell widget tests (WI-36): the screen under a real ProviderScope
// with a mocked launcher — scrubbing drives the previewed frame, the timeline
// pane shows the resolved table, and the render button launches the CLI for
// the selected lesson.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' hide RenderProgress;
import 'package:fluvie_example/inspector/inspector_screen.dart';
import 'package:fluvie_example/inspector/providers.dart';
import 'package:fluvie_example/inspector/render_launcher.dart';
import 'package:fluvie_example/playground/playground_view_model.dart';
import 'package:mocktail/mocktail.dart';

import '../playground/fake_playground_backend.dart';

final class _MockRenderLauncher extends Mock implements RenderLauncher {}

void main() {
  late _MockRenderLauncher launcher;

  setUp(() {
    launcher = _MockRenderLauncher();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          renderLauncherProvider.overrideWithValue(launcher),
          // The right pane now defaults to the Playground (Code tab); a fake
          // backend keeps its init validation deterministic and offline.
          playgroundBackendProvider.overrideWithValue(FakePlaygroundBackend()),
        ],
        child: const MaterialApp(home: InspectorScreen()),
      ),
    );
    // The D1 post-frame pass resolves the composition; the pump applies it.
    await tester.pump();
  }

  int previewedFrame(WidgetTester tester) =>
      tester.widget<FrameProvider>(find.byType(FrameProvider)).frame;

  testWidgets('scrubbing the slider changes the previewed frame', (tester) async {
    await pumpScreen(tester);

    expect(previewedFrame(tester), 0); // playback opens at the start

    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pump();

    final after = previewedFrame(tester);
    expect(after, isNot(0));
    expect(find.textContaining('frame $after'), findsOneWidget);
  });

  testWidgets('the inspector panel shows the resolved schedule (WI-22)', (tester) async {
    await pumpScreen(tester);
    // The inspector panel now lives behind the Motions tab (Code is the default).
    await tester.tap(find.text('Motions'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // finish the tab swap

    expect(find.text('Resolved schedule'), findsOneWidget);
    expect(find.textContaining('120 frames @ 30 fps'), findsOneWidget);
    expect(find.text('Motions'), findsWidgets); // the tab label and the panel header
    expect(find.textContaining('s0e0'), findsWidgets);
  });

  testWidgets('selecting a lesson swaps the preview and resets to frame 0', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Timing and triggers'));
    await tester.pump(); // rebuild with the new lesson
    await tester.pump(); // its post-frame resolution pass

    expect(previewedFrame(tester), 0); // a fresh lesson opens at the start

    // The frame-count readout lives in the inspector panel, behind the Motions tab.
    await tester.tap(find.text('Motions'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('300 frames @ 30 fps'), findsOneWidget);
  });

  testWidgets('the render button launches the CLI for the selected lesson', (tester) async {
    when(() => launcher.render(any(), onProgress: any(named: 'onProgress'))).thenAnswer(
      (_) async => const RenderLaunchResult(exitCode: 0, stdout: 'encoded 120 frames', stderr: ''),
    );
    await pumpScreen(tester);

    await tester.tap(find.text('Render MP4'));
    await tester.pump();

    verify(() => launcher.render('01_hello_video', onProgress: any(named: 'onProgress'))).called(1);
    expect(find.textContaining('encoded 120 frames'), findsOneWidget);
  });

  testWidgets('the bar is determinate at 0 / N immediately, before any frame', (tester) async {
    // The seeded total means a percentage shows during flutter-test startup,
    // not an indeterminate "Starting ..." bar with no number (the bug report).
    final gate = Completer<RenderLaunchResult>();
    when(
      () => launcher.render(any(), onProgress: any(named: 'onProgress')),
    ).thenAnswer((_) => gate.future); // never calls onProgress
    await pumpScreen(tester);

    await tester.tap(find.text('Render MP4'));
    await tester.pump();

    // Lesson 01 is 120 frames; the bar shows 0 / 120 (0%) with a known value.
    expect(find.textContaining('0 / 120 frames'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, 0.0, reason: 'a seeded total makes the bar determinate, not endless');

    gate.complete(const RenderLaunchResult(exitCode: 0, stdout: 'done', stderr: ''));
    await tester.pumpAndSettle();
  });

  testWidgets('a live progress callback shows the frame count and bar', (tester) async {
    // Hold the render open so the running UI (bar + readout) is observable, then
    // drive a progress tick through the launcher's callback.
    final gate = Completer<RenderLaunchResult>();
    when(() => launcher.render(any(), onProgress: any(named: 'onProgress'))).thenAnswer((
      invocation,
    ) {
      final onProgress = invocation.namedArguments[#onProgress] as void Function(RenderProgress)?;
      onProgress?.call(const RenderProgress(completed: 30, total: 120));
      return gate.future;
    });
    await pumpScreen(tester);

    await tester.tap(find.text('Render MP4'));
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('30 / 120 frames'), findsOneWidget);

    gate.complete(const RenderLaunchResult(exitCode: 0, stdout: 'done', stderr: ''));
    await tester.pumpAndSettle();
  });

  testWidgets('play button switches to pause icon and back', (tester) async {
    await pumpScreen(tester);

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();

    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNothing);

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('fps dropdown is present with 30 fps selected by default', (tester) async {
    await pumpScreen(tester);

    expect(find.text('30 fps'), findsOneWidget);
  });

  testWidgets('long render output scrolls in a bounded box instead of overflowing', (tester) async {
    final longOutput = List.filled(80, 'line of very long render output').join('\n');
    when(() => launcher.render(any(), onProgress: any(named: 'onProgress'))).thenAnswer(
      (_) async => RenderLaunchResult(exitCode: 0, stdout: longOutput, stderr: ''),
    );
    await pumpScreen(tester);

    await tester.tap(find.text('Render MP4'));
    await tester.pump();

    // The output sits inside a bounded scroll view so a long tail never
    // overflows the render bar.
    final scrollable = find.ancestor(
      of: find.textContaining('line of very long render output'),
      matching: find.byType(SingleChildScrollView),
    );
    expect(scrollable, findsOneWidget);
    expect(
      find.ancestor(of: scrollable, matching: find.byType(ConstrainedBox)),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
}
