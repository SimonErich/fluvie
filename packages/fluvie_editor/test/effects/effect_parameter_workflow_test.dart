import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_editor/src/effects/effect_object_editor.dart';
import 'package:fluvie_editor/src/effects/effect_text_editor.dart';
import 'package:fluvie_editor/src/inspector/inspector_text_field.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  for (final field in ['particles', 'uniforms']) {
    testWidgets('$field draft validates before applying and recovers from errors', (tester) async {
      final accepted = <Map<String, Object?>>[];
      var spec = EffectSpec.fromJson(
        field == 'particles'
            ? {'kind': 'particles'}
            : {'kind': 'shader', 'asset': 'shaders/grain.frag'},
      );
      await tester.pumpWidget(
        OiApp(
          home: StatefulBuilder(
            builder: (context, setState) => EffectObjectEditor(
              spec: spec,
              name: field,
              onChanged: (value) {
                accepted.add(value);
                setState(() => spec = EffectSpec.fromJson({...spec.toJson(), field: value}));
              },
            ),
          ),
        ),
      );
      void draft(String value) =>
          tester.widget<InspectorTextField>(find.byType(InspectorTextField)).onChanged(value);
      draft('[]');
      await tester.tap(find.text('Apply $field'));
      await tester.pump();
      expect(accepted, isEmpty);
      expect(find.textContaining('Expected a JSON object'), findsOneWidget);
      draft('{broken');
      await tester.tap(find.text('Apply $field'));
      await tester.pump();
      expect(accepted, isEmpty);
      draft(field == 'particles' ? '{"kind":"unknown"}' : '{"amount":"wrong"}');
      await tester.tap(find.text('Apply $field'));
      await tester.pump();
      expect(accepted, isEmpty, reason: 'Nested values must validate before entering history');
      draft(field == 'particles' ? '{"kind":"snow"}' : '{"amount":0.4,"seed":2}');
      await tester.tap(find.text('Apply $field'));
      await tester.pump();
      expect(accepted, hasLength(1));
      expect(
        spec.object(field),
        field == 'particles' ? {'kind': 'snow'} : {'amount': 0.4, 'seed': 2},
      );
      expect(find.textContaining('FormatException'), findsNothing);
      if (field == 'particles') {
        for (final kind in ['confetti', 'sparkle', 'snow']) {
          await tester.tap(find.text(kind));
          await tester.pump();
          expect(spec.object(field), {'kind': kind});
        }
      }
      await tester.tap(find.text('Apply $field'));
      await tester.pump();
      expect(accepted.last, spec.object(field));
      await tester.enterText(
        find.byType(EditableText),
        field == 'particles' ? '{"kind":"confetti"}' : '{"amount":0.8}',
      );
      await tester.tap(find.text('Apply $field'));
      await tester.pump();
      expect(
        spec.object(field),
        field == 'particles' ? {'kind': 'confetti'} : {'amount': 0.8},
        reason: 'Apply must use text still focused in the editor',
      );
    });
  }
  testWidgets('text effect parameter preserves authored value and can reset to default', (
    tester,
  ) async {
    var spec = EffectSpec.fromJson(const {'kind': 'shader', 'asset': 'shaders/grain.frag'});
    final values = <String?>[];
    await tester.pumpWidget(
      OiApp(
        home: StatefulBuilder(
          builder: (context, setState) => EffectTextEditor(
            spec: spec,
            name: 'asset',
            onChanged: (value) {
              values.add(value);
              final json = {...spec.toJson()}..remove('asset');
              if (value != null) json['asset'] = value;
              setState(() => spec = EffectSpec.fromJson(json));
            },
          ),
        ),
      ),
    );
    tester
        .widget<InspectorTextField>(find.byType(InspectorTextField))
        .onChanged('  shaders/bloom.frag  ');
    await tester.pump();
    expect(values, ['shaders/bloom.frag']);
    tester.widget<InspectorTextField>(find.byType(InspectorTextField)).onChanged('../secret');
    await tester.pump();
    expect(values, ['shaders/bloom.frag']);
    expect(find.textContaining('FluvieSpecError'), findsOneWidget);
    tester.widget<InspectorTextField>(find.byType(InspectorTextField)).onChanged('');
    await tester.pump();
    expect(values.last, isNull);
    expect(spec.text('asset'), isNull);
  });
}
