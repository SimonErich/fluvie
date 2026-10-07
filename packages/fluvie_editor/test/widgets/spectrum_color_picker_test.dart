import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_editor/src/widgets/spectrum_slider.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

Future<List<Color>> _pump(
  WidgetTester tester, {
  Color color = const Color(0xFFFF0000),
  List<Color> palette = const [],
}) async {
  final changes = <Color>[];
  await tester.pumpWidget(
    OiThemeScope(
      data: OiThemeData.dark(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 220,
            child: SpectrumColorPicker(color: color, palette: palette, onChanged: changes.add),
          ),
        ),
      ),
    ),
  );
  return changes;
}

void main() {
  testWidgets('tapping the SV area picks saturation and value', (tester) async {
    final changes = await _pump(tester);
    // The area's center: half saturation, half value, same hue.
    await tester.tapAt(tester.getCenter(find.byType(SaturationValueArea)));
    await tester.pump();
    final hsv = HSVColor.fromColor(changes.single);
    expect(hsv.hue, closeTo(0, 1));
    expect(hsv.saturation, closeTo(0.5, 0.05));
    expect(hsv.value, closeTo(0.5, 0.05));
  });

  testWidgets('the hue slider re-hues without losing saturation', (tester) async {
    final changes = await _pump(tester);
    await tester.tapAt(tester.getCenter(find.byType(HueSlider)));
    await tester.pump();
    final hsv = HSVColor.fromColor(changes.single);
    expect(hsv.hue, closeTo(180, 6));
    expect(hsv.saturation, closeTo(1, 0.01));
  });

  testWidgets('the alpha slider fades the color', (tester) async {
    final changes = await _pump(tester);
    await tester.tapAt(tester.getCenter(find.byType(AlphaSlider)));
    await tester.pump();
    expect(changes.single.a, closeTo(0.5, 0.05));
  });

  testWidgets('the hex field parses six and eight digit colors', (tester) async {
    final changes = await _pump(tester);
    await tester.enterText(find.byType(EditableText), '#2ECC8F');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(changes.single, const Color(0xFF2ECC8F));

    await tester.enterText(find.byType(EditableText), '802ECC8F');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(changes.last, const Color(0x802ECC8F));
  });

  testWidgets('bad hex reverts without a change', (tester) async {
    final changes = await _pump(tester);
    await tester.enterText(find.byType(EditableText), '#12');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(changes, isEmpty);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '#FF0000',
    );
  });

  testWidgets('a palette swatch picks its color directly', (tester) async {
    final changes = await _pump(tester, palette: const [Color(0xFF123456)]);
    await tester.tapAt(tester.getTopLeft(find.byType(Wrap)) + const Offset(9, 9));
    await tester.pump();
    expect(changes.single, const Color(0xFF123456));
  });
}
