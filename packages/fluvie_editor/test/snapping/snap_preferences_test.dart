import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

void main() {
  test('the defaults: snapping on, rulers off, no grid', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final prefs = container.read(snapPreferencesProvider);
    expect(prefs.snapping, isTrue);
    expect(prefs.rulers, isFalse);
    expect(prefs.gridSpacing, isNull);
  });

  test('toggles and the grid setting round-trip', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(snapPreferencesProvider.notifier)..toggleRulers();
    expect(container.read(snapPreferencesProvider).rulers, isTrue);
    controller.toggleRulers();
    expect(container.read(snapPreferencesProvider).rulers, isFalse);

    controller.toggleSnapping();
    expect(container.read(snapPreferencesProvider).snapping, isFalse);

    controller.setGridSpacing(50);
    expect(container.read(snapPreferencesProvider).gridSpacing, 50);
    controller.setGridSpacing(null);
    expect(container.read(snapPreferencesProvider).gridSpacing, isNull);
  });

  test('equality follows the value', () {
    const a = SnapPreferences();
    const b = SnapPreferences();
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(const SnapPreferences(rulers: true)));
    expect('${const SnapPreferences(gridSpacing: 8)}', contains('8'));
  });
}
