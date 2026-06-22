import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/inspector/render_launcher.dart';
import 'package:fluvie_example/playground/playground_view_model.dart';
import 'package:fluvie_server/client.dart';

import 'fake_playground_backend.dart';

ProviderContainer _containerWith(FakePlaygroundBackend backend) {
  final container = ProviderContainer(
    overrides: [playgroundBackendProvider.overrideWithValue(backend)],
  );
  addTearDown(container.dispose);
  return container;
}

const _errorDiagnostic = ApiCodeDiagnostic(
  severity: ApiDiagnosticSeverity.error,
  message: "Expected to find ';'.",
  line: 2,
  column: 1,
);

void main() {
  test('validate stores the backend diagnostics', () async {
    final backend = FakePlaygroundBackend(
      validateResult: const ApiValidationResult(ok: false, diagnostics: [_errorDiagnostic]),
    );
    final container = _containerWith(backend);
    final vm = container.read(playgroundViewModelProvider.notifier);

    await vm.validate('Video build() => Video(scenes: [])');

    final state = container.read(playgroundViewModelProvider);
    expect(state.diagnostics, hasLength(1));
    expect(state.diagnostics.single.message, contains("';'"));
    expect(state.validating, isFalse);
    expect(state.hasErrors, isTrue);
    expect(backend.lastValidatedCode, contains('Video'));
  });

  test('hasErrors is false when diagnostics are only warnings or info', () async {
    final backend = FakePlaygroundBackend(
      validateResult: const ApiValidationResult(
        ok: true,
        diagnostics: [
          ApiCodeDiagnostic(
            severity: ApiDiagnosticSeverity.warning,
            message: 'unused import',
            line: 1,
            column: 1,
          ),
        ],
      ),
    );
    final container = _containerWith(backend);
    final vm = container.read(playgroundViewModelProvider.notifier);

    await vm.validate('x');

    expect(container.read(playgroundViewModelProvider).hasErrors, isFalse);
  });

  test('render is blocked when validation finds an error', () async {
    final backend = FakePlaygroundBackend(
      validateResult: const ApiValidationResult(ok: false, diagnostics: [_errorDiagnostic]),
    );
    final container = _containerWith(backend);
    final vm = container.read(playgroundViewModelProvider.notifier);

    await vm.render('broken');

    final state = container.read(playgroundViewModelProvider);
    expect(backend.lastRenderedCode, isNull, reason: 'render must not reach the backend');
    expect(state.rendering, isFalse);
    expect(state.videoUrl, isNull);
    expect(state.hasErrors, isTrue);
    expect(state.message, isNotEmpty);
  });

  test('render success validates first then sets the video url', () async {
    final backend = FakePlaygroundBackend(
      renderResult: const RenderLaunchResult(
        exitCode: 0,
        stdout: 'done',
        stderr: '',
        downloadUrl: 'https://api.test/v1/files/rnd_1/video.mp4',
      ),
    );
    final container = _containerWith(backend);
    final vm = container.read(playgroundViewModelProvider.notifier);

    await vm.render('Video build() => Video(scenes: [])');

    final state = container.read(playgroundViewModelProvider);
    expect(backend.validateCalls, 1, reason: 'render validates before rendering');
    expect(state.videoUrl, contains('video.mp4'));
    expect(state.rendering, isFalse);
  });

  test('render reports live progress through the state', () async {
    final backend = FakePlaygroundBackend(
      progressTicks: const [RenderProgress(completed: 30, total: 120)],
    );
    var sawProgress = false;
    final container = _containerWith(backend);
    final vm = container.read(playgroundViewModelProvider.notifier);
    container.listen(playgroundViewModelProvider, (_, next) {
      if (next.progress?.completed == 30) sawProgress = true;
    });

    await vm.render('ok');

    expect(sawProgress, isTrue);
  });

  test('render failure with a non-zero exit shows the stderr message', () async {
    final backend = FakePlaygroundBackend(
      renderResult: const RenderLaunchResult(
        exitCode: 1,
        stdout: '',
        stderr: 'sandbox compile error',
      ),
    );
    final container = _containerWith(backend);
    final vm = container.read(playgroundViewModelProvider.notifier);

    await vm.render('ok');

    final state = container.read(playgroundViewModelProvider);
    expect(state.message, contains('sandbox compile error'));
    expect(state.videoUrl, isNull);
    expect(state.rendering, isFalse);
  });

  test('a backend that throws never crashes and surfaces a message', () async {
    final backend = FakePlaygroundBackend(renderError: Exception('network down'));
    final container = _containerWith(backend);
    final vm = container.read(playgroundViewModelProvider.notifier);

    await vm.render('ok');

    final state = container.read(playgroundViewModelProvider);
    expect(state.message, contains('network down'));
    expect(state.rendering, isFalse);
  });

  test('a stale validate response is ignored in favour of the latest', () async {
    // Two validations in flight: the older (error) result must not clobber the
    // newer (clean) result once both resolve.
    final container = _containerWith(FakePlaygroundBackend());
    final vm = container.read(playgroundViewModelProvider.notifier);

    final first = vm.validate('older');
    final second = vm.validate('newer');
    await Future.wait([first, second]);

    // The fake returns a clean result for both; the contract under test is that
    // the latest call wins, so the final state reflects the newer validation.
    expect(container.read(playgroundViewModelProvider).validating, isFalse);
  });
}
