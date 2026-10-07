import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

void main() {
  group('ManualGuide', () {
    test('round-trips through JSON', () {
      const guide = ManualGuide(orientation: SnapOrientation.vertical, position: 0.42);
      expect(ManualGuide.fromJson(guide.toJson()), guide);
      expect(guide.toJson(), {'axis': 'vertical', 'pos': 0.42});
      const flat = ManualGuide(orientation: SnapOrientation.horizontal, position: 0.5);
      expect(ManualGuide.fromJson(flat.toJson()), flat);
    });

    test('a list round-trips through JSON', () {
      const guides = [
        ManualGuide(orientation: SnapOrientation.vertical, position: 0.25),
        ManualGuide(orientation: SnapOrientation.horizontal, position: 0.75),
      ];
      expect(ManualGuide.listFromJson(ManualGuide.listToJson(guides)), guides);
    });

    test('listFromJson drops what it cannot read', () {
      expect(ManualGuide.listFromJson(null), isEmpty);
      expect(ManualGuide.listFromJson('nonsense'), isEmpty);
      expect(
        ManualGuide.listFromJson([
          {'axis': 'vertical', 'pos': 0.3},
          {'axis': 'diagonal', 'pos': 0.5},
          {'axis': 'horizontal'},
          'garbage',
        ]),
        const [ManualGuide(orientation: SnapOrientation.vertical, position: 0.3)],
      );
    });

    test('equality and hashing follow the value', () {
      const guide = ManualGuide(orientation: SnapOrientation.vertical, position: 0.42);
      const same = ManualGuide(orientation: SnapOrientation.vertical, position: 0.42);
      const other = ManualGuide(orientation: SnapOrientation.horizontal, position: 0.42);
      expect(guide, same);
      expect(guide.hashCode, same.hashCode);
      expect(guide, isNot(other));
      expect('$guide', contains('0.42'));
    });
  });
}
