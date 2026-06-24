import 'package:cli_quickstart/preview/preview_view_model.dart';
import 'package:cli_quickstart/services/output_probe_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProbe implements OutputProbeService {
  _FakeProbe(this.result);

  final RenderOutput? result;

  @override
  String get outputPath => 'build/whisker_standup.mp4';

  @override
  Future<RenderOutput?> probe() async => result;
}

ProviderContainer _container(OutputProbeService probe) {
  final container = ProviderContainer(
    overrides: [outputProbeServiceProvider.overrideWithValue(probe)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('build() exposes the render command and starts with no output', () {
    final container = _container(_FakeProbe(null));

    final state = container.read(previewViewModelProvider);

    expect(state.command, contains('render whisker_standup'));
    expect(state.command, contains('build/whisker_standup.mp4'));
    expect(state.hasOutput, isFalse);
  });

  test('refresh() surfaces a rendered output when the probe finds one', () async {
    final container = _container(
      _FakeProbe(const RenderOutput(path: 'build/whisker_standup.mp4', bytes: 2048)),
    );

    await container.read(previewViewModelProvider.notifier).refresh();
    final state = container.read(previewViewModelProvider);

    expect(state.hasOutput, isTrue);
    expect(state.output!.bytes, 2048);
  });
}
