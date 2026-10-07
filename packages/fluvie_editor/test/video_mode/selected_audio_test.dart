import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

void main() {
  test('selects and clears one audio track at a time', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(audioSelectionProvider), isNull);
    container
        .read(audioSelectionProvider.notifier)
        .select(const SelectedAudioTrack(scene: null, index: 1));
    expect(container.read(audioSelectionProvider), const SelectedAudioTrack(scene: null, index: 1));
    container
        .read(audioSelectionProvider.notifier)
        .select(const SelectedAudioTrack(scene: 2, index: 0));
    expect(container.read(audioSelectionProvider), const SelectedAudioTrack(scene: 2, index: 0));
    container.read(audioSelectionProvider.notifier).clear();
    expect(container.read(audioSelectionProvider), isNull);
  });

  test('an element selection clears the audio selection', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(audioSelectionProvider.notifier)
        .select(const SelectedAudioTrack(scene: null, index: 0));
    container.read(selectionProvider.notifier).select({'el-a'});
    expect(container.read(audioSelectionProvider), isNull);
  });

  test('selections are value-equal and print themselves', () {
    const a = SelectedAudioTrack(scene: null, index: 1);
    const b = SelectedAudioTrack(scene: null, index: 1);
    const c = SelectedAudioTrack(scene: 1, index: 1);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
    expect('$c', contains('scene 1'));
  });
}
