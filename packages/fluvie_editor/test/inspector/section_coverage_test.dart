import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show VideoSize;
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_editor/src/inspector/background_editor.dart';
import 'package:fluvie_editor/src/inspector/inspector_sections.dart';
import 'package:fluvie_editor/src/inspector/transform_section.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiPropertyGrid, OiSelect, OiSwitch, OiThemeData;

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  OiApp(
    title: 'test',
    theme: OiThemeData.dark(),
    home: Center(
      child: SizedBox(width: 280, child: SingleChildScrollView(child: child)),
    ),
  ),
);

Future<void> _commitFirstField(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(EditableText).first, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  group('style rows per element type', () {
    Future<List<Map<String, Object?>>> rowsFor(
      WidgetTester tester,
      Map<String, Object?> element,
    ) async {
      final patches = <Map<String, Object?>>[];
      await _pump(
        tester,
        OiPropertyGrid(
          properties: styleRowsFor(element, (patch, {mergeGroup}) => patches.add(patch)),
        ),
      );
      return patches;
    }

    testWidgets('Shape edits stroke width', (tester) async {
      final patches = await rowsFor(tester, const {'type': 'Shape', 'kind': 'rect'});
      await _commitFirstField(tester, '6');
      expect(patches.single, {'strokeWidth': 6.0});
    });

    testWidgets('Arrow edits head length', (tester) async {
      final patches = await rowsFor(tester, const {
        'type': 'Arrow',
        'from': {'x': 0, 'y': 0},
        'to': {'x': 1, 'y': 1},
        'strokeWidth': 3,
      });
      await tester.enterText(find.byType(EditableText).at(1), '24');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(patches.single, {'headLength': 24.0});
    });

    testWidgets('Connector toggles the elbow', (tester) async {
      final patches = await rowsFor(tester, const {
        'type': 'Connector',
        'from': {'x': 0, 'y': 0},
        'to': {'x': 1, 'y': 1},
      });
      await tester.tap(find.byType(OiSwitch));
      expect(patches.single, {'elbow': true});
    });

    testWidgets('Image edits radius and fit', (tester) async {
      final patches = await rowsFor(tester, const {
        'type': 'Image',
        'source': {'kind': 'asset', 'value': 'p.png'},
      });
      await _commitFirstField(tester, '16');
      expect(patches.single, {'cornerRadius': 16.0});

      await tester.tap(find.byType(OiSelect<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('contain').last);
      await tester.pumpAndSettle();
      expect(patches.last, {'fit': 'contain'});
    });

    testWidgets('Clip edits volume', (tester) async {
      final patches = await rowsFor(tester, const {
        'type': 'Clip',
        'source': {'kind': 'asset', 'value': 'a.mp4'},
      });
      await _commitFirstField(tester, '0.5');
      expect(patches.single, {'volume': 0.5});
    });

    testWidgets('Counter edits from and to', (tester) async {
      final patches = await rowsFor(tester, const {'type': 'Counter', 'to': 100});
      await _commitFirstField(tester, '10');
      expect(patches.single, {'from': 10.0});
      await tester.enterText(find.byType(EditableText).at(1), '250');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(patches.last, {'to': 250.0});
    });

    testWidgets('Box picks a color through the swatch dialog', (tester) async {
      final patches = await rowsFor(tester, const {'type': 'Box', 'color': '#6C5CE7'});
      await tester.tap(find.bySemanticsLabel('Color').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, '#FF0000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(patches.single, {'color': '#FFFF0000'});
    });
  });

  group('background kinds', () {
    Future<List<Map<String, Object?>?>> pumpBackground(
      WidgetTester tester,
      Map<String, Object?>? background,
    ) async {
      var current = background;
      final patches = <Map<String, Object?>?>[];
      await _pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => BackgroundEditor(
            background: current,
            onPatch: (next, {mergeGroup}) {
              patches.add(next);
              setState(() => current = next);
            },
          ),
        ),
      );
      return patches;
    }

    testWidgets('gradient stops edit through the gradient editor', (tester) async {
      final patches = await pumpBackground(tester, {
        'kind': 'gradient',
        'colors': ['#101018', '#2D3436'],
      });
      // Select the second stop on the bar, then pick its color.
      final bar = tester.getRect(find.byKey(const ValueKey('gradient-stops-bar')));
      await tester.tapAt(Offset(bar.right - 8, bar.center.dy));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Stop color'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, '#00FF00');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(patches.single!['colors'], ['#101018', '#FF00FF00']);
    });

    testWidgets('image backgrounds edit their source', (tester) async {
      final patches = await pumpBackground(tester, {'kind': 'image', 'source': 'a.png'});
      await tester.enterText(find.byType(EditableText).last, 'b.png');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(patches.single, {'kind': 'image', 'source': 'b.png'});
    });

    testWidgets('switching kinds seeds each shape; none clears', (tester) async {
      Future<Map<String, Object?>?> seeded(String kind, {String from = 'color'}) async {
        final patches = await pumpBackground(
          tester,
          from == 'color' ? {'kind': 'color', 'color': '#101018'} : null,
        );
        // Driving onChanged directly: the popup's own mechanics belong to
        // obers_ui; this pins the editor's seeding per kind.
        tester.widget<OiSelect<String>>(find.byType(OiSelect<String>)).onChanged!(kind);
        await tester.pumpAndSettle();
        return patches.last;
      }

      expect((await seeded('gradient'))!['kind'], 'gradient');
      expect(await seeded('video'), {'kind': 'video', 'source': ''});
      expect(await seeded('vhs'), {'kind': 'vhs'});
      expect(await seeded('none'), isNull);
      expect(await seeded('color', from: 'none'), {'kind': 'color', 'color': '#101018'});
    });
  });

  group('transform extras', () {
    testWidgets('W, angle, and slide height fields commit', (tester) async {
      final commands = <EditorCommand>[];
      await _pump(
        tester,
        Column(
          children: [
            TransformSection(
              id: 'el-a',
              transform: const {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5, 'rotation': 30},
              canvas: const VideoSize(320, 180),
              onCommand: commands.add,
            ),
            SlideSizeSection(width: 320, height: 180, onChanged: (w, h) {}),
          ],
        ),
      );
      // Fields: X, Y, W, H, Angle, Opacity.
      await tester.enterText(find.byType(EditableText).at(2), '80');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      var command = commands.single as SetTransformsCommand;
      expect(command.transforms['el-a']!['w'], closeTo(0.25, 1e-9));

      await tester.enterText(find.byType(EditableText).at(4), '0');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      command = commands.last as SetTransformsCommand;
      expect(command.transforms['el-a']!.containsKey('rotation'), isFalse);
    });
  });

  testWidgets('the tip shows after a hover delay and hides on exit', (tester) async {
    await _pump(
      tester,
      const EditorTip(message: 'Hello tip', child: SizedBox(width: 40, height: 20)),
    );
    expect(find.text('Hello tip'), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(EditorTip)));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Hello tip'), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(find.text('Hello tip'), findsNothing);
  });
}
