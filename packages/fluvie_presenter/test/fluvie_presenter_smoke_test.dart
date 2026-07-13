import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

void main() {
  test('the barrel resolves and carries the package doc surface', () {
    // The barrel is the package's single public entry. This smoke test exists
    // so the workspace wiring epic has a red test before the package compiles:
    // it fails to compile until lib/fluvie_presenter.dart exists.
    expect(fluviePresenterPackageName, 'fluvie_presenter');
  });
}
