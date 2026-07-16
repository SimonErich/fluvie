import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  SelectionController controller() => container.read(selectionProvider.notifier);
  Set<String> selection() => container.read(selectionProvider);

  test('starts empty', () {
    expect(selection(), isEmpty);
  });

  test('a click selects exactly one element', () {
    controller()
      ..click('el-a')
      ..click('el-b');
    expect(selection(), {'el-b'});
  });

  test('a shift-click adds and removes', () {
    controller()
      ..click('el-a')
      ..click('el-b', additive: true)
      ..click('el-a', additive: true);
    expect(selection(), {'el-b'});
  });

  test('clicking empty canvas clears; escape clears', () {
    controller()
      ..click('el-a')
      ..click(null);
    expect(selection(), isEmpty);
    controller()
      ..click('el-a')
      ..clear();
    expect(selection(), isEmpty);
  });

  test('a marquee replaces the selection; additive extends it', () {
    controller()
      ..click('el-x')
      ..marquee({'el-a', 'el-b'});
    expect(selection(), {'el-a', 'el-b'});
    controller().marquee({'el-c'}, additive: true);
    expect(selection(), {'el-a', 'el-b', 'el-c'});
  });

  test('select replaces wholesale (undo re-selection uses it)', () {
    controller()
      ..click('el-a')
      ..select({'el-p', 'el-q'});
    expect(selection(), {'el-p', 'el-q'});
  });

  test('prune drops ids that left the document', () {
    controller().select({'el-a', 'el-gone'});
    controller().prune({'el-a'});
    expect(selection(), {'el-a'});
  });
}
