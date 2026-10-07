import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show KeyframedNumber;
import 'package:fluvie/rendering.dart' show integrateClipSpeedRamp;
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

import 'shared_clip_speed_test.dart' show sharedDeck;
import 'transition_edits_test.dart' show deck;

Future<void> pumpSpeed(WidgetTester tester, DocumentHistory history, String id) =>
    tester.pumpWidget(
      OiApp(
        home: ListenableBuilder(
          listenable: history,
          builder: (context, _) => SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: ClipSpeedSection(
                key: ValueKey(id),
                document: history.document,
                id: id,
                onCommand: history.dispatch,
              ),
            ),
          ),
        ),
      ),
    );

void press(WidgetTester tester, String label) => tester
    .widget<OiButton>(
      find.ancestor(of: find.text(label), matching: find.byType(OiButton)).first,
    )
    .onTap!();

void main() {
  testWidgets('speed ramp stop value, position and easing controls preserve the source range', (
    tester,
  ) async {
    final history = DocumentHistory(deck());
    addTearDown(history.dispose);
    await tester.pumpWidget(
      OiApp(
        home: ListenableBuilder(
          listenable: history,
          builder: (context, _) => SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: ClipSpeedSection(
                document: history.document,
                id: 'a',
                onCommand: history.dispatch,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Add speed ramp'));
    await tester.pump();
    final add = tester.widget<OiButton>(
      find.ancestor(of: find.text('Add middle speed stop'), matching: find.byType(OiButton)).first,
    );
    add.onTap!();
    await tester.pump();
    final position = tester.widget<MathNumberInput>(find.byKey(const ValueKey('speed-position-1')));
    position.onChanged(25);
    await tester.pump();
    final stop = tester.widget<MathNumberInput>(find.byKey(const ValueKey('speed-stop-1')));
    stop.onChanged(1.5);
    await tester.pump();
    tester.widget<EasingCurveEditor>(find.byType(EasingCurveEditor).first).onChanged('inOut');
    await tester.pump();
    final json = history.document.elementJson('a')!;
    final ramp = KeyframedNumber.maybeFromJson(json['speed'])!;
    expect(ramp.values, hasLength(3));
    expect(ramp.toJson()['positions'], ['0.0r', '0.25r', '1.0r']);
    expect(json['trim'], {'from': '1.0s', 'to': '3.0s'});
    final length = VideoLaneModel.build(
      document: history.document,
    ).elementBars['el:a']!.window.durationFrames;
    expect(integrateClipSpeedRamp(ramp, fps: 30, windowFrames: length).last, closeTo(2, 1e-10));
    expect(tester.takeException(), isNull);
    press(tester, 'Add middle speed stop');
    await tester.pump();
    expect(
      KeyframedNumber.maybeFromJson(history.document.elementJson('a')!['speed'])!.values,
      hasLength(4),
    );
    press(tester, 'Remove middle speed stop');
    await tester.pump();
    expect(
      KeyframedNumber.maybeFromJson(history.document.elementJson('a')!['speed'])!.values,
      hasLength(3),
    );
    press(tester, 'Use constant speed');
    await tester.pump();
    expect(history.document.elementJson('a')!['speed'], 1);
  });

  testWidgets('speed number and reverse disclose audio behavior and owner refusal', (tester) async {
    final history = DocumentHistory(deck());
    addTearDown(history.dispose);
    await pumpSpeed(tester, history, 'a');
    tester.widget<MathNumberInput>(find.byType(MathNumberInput)).onChanged(2);
    await tester.pump();
    expect(history.document.elementJson('a')!['speed'], 2);
    press(tester, 'Reverse: off');
    await tester.pump();
    expect(find.text('Reversed clips play without source audio.'), findsOneWidget);
    expect(history.document.elementJson('a')!['speed'], -2);
    tester.widget<MathNumberInput>(find.byType(MathNumberInput)).onChanged(0.1);
    await tester.pump();
    expect(find.textContaining('does not fit'), findsOneWidget);
    expect(history.document.elementJson('a')!['speed'], -2);
  });

  testWidgets('overlay and non-primary shared member ramp controls use their own window', (
    tester,
  ) async {
    final local = deck();
    final overlay = EditorDocument.fromJson({
      ...local.toJson(),
      'overlays': [
        {...local.elementJson('a')!, 'id': 'overlay'},
      ],
    });
    for (final entry in [(overlay, 'overlay'), (sharedDeck(), 'clip1')]) {
      final history = DocumentHistory(entry.$1);
      await pumpSpeed(tester, history, entry.$2);
      press(tester, 'Add speed ramp');
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Speed ramp · source range preserved'), findsOneWidget);
      press(tester, 'Add middle speed stop');
      await tester.pump();
      final position = tester.widget<MathNumberInput>(
        find.byKey(const ValueKey('speed-position-1')),
      );
      expect(position.value, 50);
      await tester.pumpWidget(const SizedBox.shrink());
      history.dispose();
    }
  });
}
