import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

Map<String, Object?> _doc(Map<String, Object?> element) => {
  'fluvieSpec': 1,
  'size': 'hd',
  'fps': 30,
  'scenes': [
    {
      'duration': '360f',
      'children': [element],
    },
  ],
};

void main() {
  group('a show window prints as the animate window argument', () {
    test('both bounds print a TimeRange over an empty animations list', () {
      final code = printVideoSpecJson(
        _doc({
          'type': 'Box',
          'color': '#6C5CE7',
          'show': {'from': '60f', 'to': '195f'},
        }),
      );
      expect(code, contains('.animate([], window: TimeRange(60.frames, 195.frames))'));
    });

    test('a missing to falls to the scene end (the defaults law)', () {
      final code = printVideoSpecJson(
        _doc({
          'type': 'Text',
          'text': 'late',
          'show': {'from': '2.5s'},
        }),
      );
      expect(code, contains('.animate([], window: TimeRange(2.5.seconds, 1.relative))'));
    });

    test('a missing from falls to the scene start', () {
      final code = printVideoSpecJson(
        _doc({
          'type': 'Text',
          'text': 'early',
          'show': {'to': '60f'},
        }),
      );
      expect(code, contains('.animate([], window: TimeRange(Time.zero, 60.frames))'));
    });

    test('the window rides the one call with animations and the anchor', () {
      final code = printVideoSpecJson(
        _doc({
          'type': 'Box',
          'color': '#6C5CE7',
          'anchor': 'badge',
          'show': {'from': '90f', 'to': '270f'},
          'animate': [
            {'preset': 'fadeIn', 'duration': '12f'},
          ],
        }),
      );
      expect(
        code,
        allOf([
          contains('Animation.fadeIn(duration: 12.frames)'),
          contains('anchor: badge'),
          contains('window: TimeRange(90.frames, 270.frames)'),
        ]),
      );
      expect(
        '.animate('.allMatches(code),
        hasLength(1),
        reason: 'one MotionTarget: the window rides the single animate call',
      );
    });

    test('no show means no window argument', () {
      final code = printVideoSpecJson(
        _doc({
          'type': 'Box',
          'color': '#6C5CE7',
          'animate': [
            {'preset': 'fadeIn'},
          ],
        }),
      );
      expect(code, isNot(contains('window:')));
    });
  });
}
