// Units on the numeric atom. The value stays a plain number in the field's own
// domain; a unit only changes how it is written and read, so nothing
// downstream has to know which unit a field wears.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  group('timecode formatting', () {
    test('counts hours, minutes, seconds and frames at the rate', () {
      expect(formatTimecode(0, 30), '00:00:00:00');
      expect(formatTimecode(29, 30), '00:00:00:29');
      expect(formatTimecode(30, 30), '00:00:01:00');
      expect(formatTimecode(90, 30), '00:00:03:00');
      expect(formatTimecode(30 * 61, 30), '00:01:01:00');
      expect(formatTimecode(30 * 3661, 30), '01:01:01:00');
    });

    test('the same frame reads differently at different rates', () {
      // Which is the point of carrying the rate with the unit.
      expect(formatTimecode(25, 25), '00:00:01:00');
      expect(formatTimecode(25, 30), '00:00:00:25');
      expect(formatTimecode(50, 24), '00:00:02:02');
      expect(formatTimecode(60, 60), '00:00:01:00');
    });

    test('a negative frame shows as the start rather than as nonsense', () {
      expect(formatTimecode(-5, 30), '00:00:00:00');
    });
  });

  group('timecode parsing', () {
    test('round-trips every rate the editor offers', () {
      for (final fps in const [24, 25, 30, 60]) {
        for (final frames in [0, 1, fps - 1, fps, fps * 61, fps * 3661 + 7]) {
          expect(
            parseTimecode(formatTimecode(frames, fps), fps),
            frames,
            reason: '$frames at ${fps}fps must survive the round trip',
          );
        }
      }
    });

    test('accepts the short forms, reading the parts from the right', () {
      // Typing four fields to move two seconds is a tax.
      expect(parseTimecode('12', 30), isNull, reason: 'one part is not a timecode');
      expect(parseTimecode('02:15', 30), 75);
      expect(parseTimecode('01:02:15', 30), 30 * 62 + 15);
      expect(parseTimecode('01:01:02:15', 30), 30 * 3662 + 15);
    });

    test('refuses a frame the rate cannot have', () {
      // 00:00:00:30 at 30fps names a frame that does not exist; carrying it
      // silently would put the playhead a frame past where the label says.
      expect(parseTimecode('00:00:00:30', 30), isNull);
      expect(parseTimecode('00:00:00:29', 30), 29);
      expect(parseTimecode('00:00:00:25', 24), isNull);
    });

    test('refuses what is not a timecode at all', () {
      for (final text in const ['', 'abc', '1:2:3:4:5', '-1:00', '00:xx:00:00']) {
        expect(parseTimecode(text, 30), isNull, reason: '"$text" is not a timecode');
      }
    });
  });

  group('units format and parse in the field domain', () {
    test('frames stay frames', () {
      const format = NumericFormat(unit: NumericUnit.frames);
      expect(format.format(120), '120f');
      expect(format.parse('120f'), 120);
      expect(format.parse('120'), 120, reason: 'the suffix is optional on input');
    });

    test('seconds convert against the rate, both ways', () {
      const format = NumericFormat(unit: NumericUnit.seconds, fps: 24);
      expect(format.format(48), '2s');
      expect(format.parse('2s'), 48);
      expect(format.parse('0.5'), 12);
    });

    test('percent carries a fraction, not a whole', () {
      const format = NumericFormat(unit: NumericUnit.percent);
      expect(format.format(0.5), '50%');
      expect(format.parse('50%'), closeTo(0.5, 1e-12));
    });

    test('degrees and plain numbers pass straight through', () {
      expect(const NumericFormat(unit: NumericUnit.degrees).format(45), '45°');
      expect(const NumericFormat(unit: NumericUnit.degrees).parse('45°'), 45);
      expect(const NumericFormat().format(3.5), '3.5');
      expect(const NumericFormat().parse('3.5'), 3.5);
    });

    test('a timecode field needs its colons', () {
      const format = NumericFormat(unit: NumericUnit.timecode);
      expect(format.format(90), '00:00:03:00');
      expect(format.parse('00:00:03:00'), 90);
      expect(format.parse('90'), isNull, reason: 'a bare number is ambiguous here');
    });

    test('nonsense parses to null rather than to zero', () {
      // Zero would be a silent edit; null leaves the field where it was.
      for (final unit in NumericUnit.values) {
        expect(NumericFormat(unit: unit).parse('  '), isNull, reason: unit.name);
        expect(NumericFormat(unit: unit).parse('nope'), isNull, reason: unit.name);
      }
    });

    test('a whole value shows without a trailing zero', () {
      expect(const NumericFormat().format(4), '4');
      expect(const NumericFormat(decimals: 2).format(4.25), '4.25');
    });
  });

  group('the field wears the unit', () {
    Future<List<double>> typeInto(
      WidgetTester tester, {
      required NumericFormat format,
      required double value,
      required String text,
    }) async {
      final changes = <double>[];
      await tester.pumpWidget(
        OiApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 220,
              child: MathNumberInput(
                label: 'At',
                value: value,
                format: format,
                onChanged: changes.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      return changes;
    }

    testWidgets('shows the value in its unit', (tester) async {
      await tester.pumpWidget(
        OiApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 220,
              child: MathNumberInput(
                label: 'At',
                value: 90,
                format: const NumericFormat(unit: NumericUnit.timecode),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('00:00:03:00'), findsOneWidget);
    });

    testWidgets('a typed timecode lands as frames', (tester) async {
      final changes = await typeInto(
        tester,
        format: const NumericFormat(unit: NumericUnit.timecode),
        value: 0,
        text: '00:00:02:15',
      );

      expect(changes, [75]);
    });

    testWidgets('a typed duration lands as frames at the field rate', (tester) async {
      final changes = await typeInto(
        tester,
        format: const NumericFormat(unit: NumericUnit.seconds, fps: 24),
        value: 0,
        text: '2s',
      );

      expect(changes, [48]);
    });

    testWidgets('the arithmetic grammar still works on a unit field', (tester) async {
      // A unit must not cost the author `+30`, which is how the inspector's
      // fields have always been nudged.
      final changes = await typeInto(
        tester,
        format: const NumericFormat(unit: NumericUnit.frames),
        value: 100,
        text: '+30',
      );

      expect(changes, [130]);
    });

    testWidgets('nonsense leaves the value where it was', (tester) async {
      final changes = await typeInto(
        tester,
        format: const NumericFormat(unit: NumericUnit.timecode),
        value: 90,
        text: 'nope',
      );

      expect(changes, isEmpty);
      expect(find.text('00:00:03:00'), findsOneWidget);
    });
  });
}
