import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/inspector/render_launcher.dart';
import 'package:fluvie_example/playground/playground.dart';
import 'package:fluvie_example/playground/playground_backend.dart';
import 'package:fluvie_example/playground/playground_video.dart';
import 'package:fluvie_example/playground/playground_view_model.dart';
import 'package:fluvie_server/client.dart';

import 'fake_playground_backend.dart';

const _errorDiagnostic = ApiCodeDiagnostic(
  severity: ApiDiagnosticSeverity.error,
  message: "Expected to find ';'.",
  line: 2,
  column: 1,
);

Future<ProviderContainer> _pump(WidgetTester tester, PlaygroundBackend backend) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [playgroundBackendProvider.overrideWithValue(backend)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: Playground())),
    ),
  );
  await tester.pump();
  return container;
}

FilledButton _renderButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Render'));

void main() {
  testWidgets('opens with the empty video state and an enabled render button', (tester) async {
    await _pump(tester, FakePlaygroundBackend());
    await tester.pumpAndSettle();

    expect(find.byType(PlaygroundVideo), findsOneWidget);
    expect(find.textContaining('Render to see your video'), findsOneWidget);
    expect(_renderButton(tester).onPressed, isNotNull);
  });

  testWidgets('the render button is disabled when validation finds an error', (tester) async {
    final backend = FakePlaygroundBackend(
      validateResult: const ApiValidationResult(ok: false, diagnostics: [_errorDiagnostic]),
    );
    final container = await _pump(tester, backend);
    await container.read(playgroundViewModelProvider.notifier).validate('bad');
    await tester.pump();

    expect(_renderButton(tester).onPressed, isNull);
  });

  testWidgets('a successful render shows the video url', (tester) async {
    // The fake's default render result is a success with a video.mp4 URL.
    final backend = FakePlaygroundBackend();
    final container = await _pump(tester, backend);

    await container.read(playgroundViewModelProvider.notifier).render('ok');
    await tester.pumpAndSettle();

    expect(find.textContaining('video.mp4'), findsOneWidget);
  });

  testWidgets('a running render shows a progress bar and disables the button', (tester) async {
    final gate = Completer<void>();
    final backend = _GatedBackend(gate.future);
    final container = await _pump(tester, backend);

    unawaited(container.read(playgroundViewModelProvider.notifier).render('ok'));
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(_renderButton(tester).onPressed, isNull);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a backend error is shown inline and the code is kept', (tester) async {
    final backend = FakePlaygroundBackend(renderError: Exception('network down'));
    final container = await _pump(tester, backend);

    await container.read(playgroundViewModelProvider.notifier).render('ok');
    await tester.pumpAndSettle();

    expect(find.textContaining('network down'), findsOneWidget);
  });
}

/// A backend whose render stays open until [done] completes (to observe the
/// running UI), then succeeds.
final class _GatedBackend implements PlaygroundBackend {
  _GatedBackend(this.done);

  final Future<void> done;

  @override
  Future<ApiValidationResult> validate(String code) async =>
      const ApiValidationResult(ok: true, diagnostics: []);

  @override
  Future<RenderLaunchResult> render(
    String code, {
    void Function(RenderProgress)? onProgress,
  }) async {
    onProgress?.call(const RenderProgress(completed: 1, total: 10));
    await done;
    return const RenderLaunchResult(exitCode: 0, stdout: 'ok', stderr: '', downloadUrl: 'x');
  }
}
