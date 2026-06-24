import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_ai/fluvie_ai.dart';
import 'package:fluvie_example/inspector/generate_view_model.dart';

const _validSpec =
    '{"fluvieSpec":1,"size":"square","fps":30,"scenes":[{"duration":"2s",'
    '"children":[{"type":"Text","text":"Hi","animate":[{"preset":"fadeIn"}]}]}]}';

ProviderContainer _containerWith(List<String> replies) {
  final container = ProviderContainer(
    overrides: [aiClientProvider.overrideWithValue(FakeAiClient(replies))],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('authors a spec on success', () async {
    final container = _containerWith([_validSpec]);
    await container.read(generateViewModelProvider.notifier).generate('a title card');

    final state = container.read(generateViewModelProvider);
    expect(state.spec, isNotNull);
    expect(state.error, isNull);
    expect(state.busy, isFalse);
  });

  test('surfaces an error when authoring fails', () async {
    final container = _containerWith(const []); // the fake runs out of replies
    await container.read(generateViewModelProvider.notifier).generate('a title card');

    final state = container.read(generateViewModelProvider);
    expect(state.spec, isNull);
    expect(state.error, isNotNull);
    expect(state.busy, isFalse);
  });

  test('an empty prompt is a no-op', () async {
    final container = _containerWith([_validSpec]);
    await container.read(generateViewModelProvider.notifier).generate('   ');

    final state = container.read(generateViewModelProvider);
    expect(state.spec, isNull);
    expect(state.busy, isFalse);
  });
}
