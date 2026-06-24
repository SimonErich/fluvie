import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/playground/ai_assistant_view_model.dart';
import 'package:fluvie_example/playground/ai_author_backend.dart';
import 'package:fluvie_example/playground/playground_code_editor.dart';
import 'package:fluvie_example/playground/playground_view_model.dart';

import 'fake_ai_author_backend.dart';
import 'fake_playground_backend.dart';

ProviderContainer _container(FakeAiAuthorBackend ai, FakePlaygroundBackend render) {
  final container = ProviderContainer(
    overrides: [
      aiAuthorBackendProvider.overrideWithValue(ai),
      playgroundBackendProvider.overrideWithValue(render),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('generate fills the editor with the generated code and renders it', () async {
    final ai = FakeAiAuthorBackend(code: 'NEW CODE');
    final render = FakePlaygroundBackend();
    final container = _container(ai, render);

    await container.read(aiAssistantViewModelProvider.notifier).generate('a blue intro');

    expect(container.read(aiAssistantViewModelProvider).phase, AiAssistantPhase.ready);
    expect(container.read(playgroundCodeControllerProvider).fullText, 'NEW CODE');
    expect(ai.lastPrompt, 'a blue intro');

    await pumpEventQueue(); // let the unawaited auto-render complete
    expect(render.lastRenderedCode, 'NEW CODE');
  });

  test('an empty prompt is rejected without calling the backend', () async {
    final ai = FakeAiAuthorBackend();
    final container = _container(ai, FakePlaygroundBackend());

    await container.read(aiAssistantViewModelProvider.notifier).generate('   ');

    expect(ai.calls, 0);
    expect(container.read(aiAssistantViewModelProvider).phase, AiAssistantPhase.idle);
    expect(container.read(aiAssistantViewModelProvider).message, contains('Describe'));
  });

  test('editWith sends the current editor code as context', () async {
    final ai = FakeAiAuthorBackend(code: 'EDITED');
    final container = _container(ai, FakePlaygroundBackend());
    container.read(playgroundCodeControllerProvider).fullText = 'ORIGINAL';

    await container.read(aiAssistantViewModelProvider.notifier).editWith('make it red');

    expect(ai.lastCurrentCode, 'ORIGINAL');
    expect(container.read(playgroundCodeControllerProvider).fullText, 'EDITED');
    expect(container.read(aiAssistantViewModelProvider).phase, AiAssistantPhase.ready);
  });

  test('a generation failure returns to idle with a message', () async {
    final ai = FakeAiAuthorBackend(error: Exception('boom'));
    final container = _container(ai, FakePlaygroundBackend());

    await container.read(aiAssistantViewModelProvider.notifier).generate('anything');

    final state = container.read(aiAssistantViewModelProvider);
    expect(state.phase, AiAssistantPhase.idle);
    expect(state.message, contains('boom'));
  });

  test('a friendly AiAuthorException is shown as-is, without a generic prefix', () async {
    final ai = FakeAiAuthorBackend(error: const AiAuthorException('Free limit reached.'));
    final container = _container(ai, FakePlaygroundBackend());

    await container.read(aiAssistantViewModelProvider.notifier).generate('anything');

    final state = container.read(aiAssistantViewModelProvider);
    expect(state.phase, AiAssistantPhase.idle);
    expect(state.message, 'Free limit reached.');
  });
}
