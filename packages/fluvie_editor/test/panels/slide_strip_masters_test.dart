import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart' show SlidePreviewService;
import 'package:obers_ui/obers_ui.dart' show OiApp, OiMenuItem, OiThemeData;

Map<String, Object?> _deck({bool masters = true}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  if (masters)
    'masters': {
      'base': {
        'children': [
          {
            'type': 'Placeholder',
            'slot': 'title',
            'transform': {'x': 0.5, 'y': 0.3, 'w': 0.8, 'h': 0.2},
          },
        ],
      },
      'closing': {'children': <Object?>[]},
    },
  'scenes': [
    {
      'duration': '60f',
      if (masters) 'master': 'base',
      'children': <Object?>[],
    },
    {'duration': '60f', 'children': <Object?>[]},
  ],
};

Future<ui.Image> _stubRender(int slide) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF123456),
  );
  return recorder.endRecording().toImage(4, 4);
}

final class _Harness {
  final List<EditorCommand> commands = [];
  final List<String> edited = [];
}

Future<_Harness> _pump(
  WidgetTester tester, {
  bool masters = true,
  List<OiMenuItem> Function(CommandScope scope)? extraMenuItems,
}) async {
  final harness = _Harness();
  final service = SlidePreviewService(renderSlide: _stubRender);
  addTearDown(service.dispose);
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: SizedBox(
        width: 180,
        child: SlideStrip(
          document: EditorDocument.fromJson(_deck(masters: masters)),
          current: 1,
          service: service,
          onSelect: (_) {},
          onCommand: harness.commands.add,
          onEditMaster: harness.edited.add,
          extraMenuItems: extraMenuItems,
        ),
      ),
    ),
  );
  await tester.pump();
  return harness;
}

void main() {
  testWidgets('the masters row lists every master; no masters, no row', (tester) async {
    await _pump(tester);
    expect(find.text('Masters'), findsOneWidget);
    expect(find.text('base'), findsOneWidget);
    expect(find.text('closing'), findsOneWidget);

    await _pump(tester, masters: false);
    expect(find.text('Masters'), findsNothing);
  });

  testWidgets('an adopting tile badges itself with its master', (tester) async {
    await _pump(tester);
    // Slide 1 adopts 'base': the tile carries a chip next to its number.
    expect(find.text('M base'), findsOneWidget);
  });

  testWidgets('the row edits and applies through the surface', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Edit master base'));
    await tester.pump();
    expect(harness.edited, ['base']);

    await tester.tap(find.bySemanticsLabel('Apply master closing to this slide'));
    await tester.pump();
    final apply = harness.commands.single as ApplyMasterCommand;
    expect(apply.name, 'closing');
    expect(apply.slide, 1, reason: 'the current slide adopts');
  });

  testWidgets('host menu items join the tile menu', (tester) async {
    var tapped = false;
    await _pump(
      tester,
      extraMenuItems: (scope) => [
        OiMenuItem(label: 'Insert template slide', onTap: () => tapped = true),
      ],
    );
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    final where = tester.getCenter(find.text('1'));
    await gesture.addPointer(location: where);
    addTearDown(gesture.removePointer);
    await gesture.down(where);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insert template slide'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });
}
