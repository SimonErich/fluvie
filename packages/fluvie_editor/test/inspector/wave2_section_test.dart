import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show knownElementTypes;
import 'package:fluvie_editor/src/inspector/inspector_sections.dart';
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

Future<List<Map<String, Object?>>> _rowsFor(
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

Future<void> _commitField(WidgetTester tester, int index, String text) async {
  await tester.enterText(find.byType(EditableText).at(index), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

Future<void> _pickOption(WidgetTester tester, Key key, String option) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  test('every element type has style rows; Group has its own section', () {
    for (final type in knownElementTypes) {
      final rows = styleRowsFor({'type': type}, (patch, {mergeGroup}) {});
      if (type == 'Group') {
        expect(rows, isEmpty, reason: 'a Group edits through the Block section');
      } else {
        expect(rows, isNotEmpty, reason: '$type has no style rows');
      }
    }
  });

  group('Typewriter', () {
    testWidgets('edits the speed as a spec time and drops invalid input', (tester) async {
      final patches = await _rowsFor(tester, const {'type': 'Typewriter', 'text': 'T'});
      await _commitField(tester, 0, '3f');
      expect(patches.single, {'speed': '3f'});
      await _commitField(tester, 0, 'not a time');
      expect(patches, hasLength(1));
    });

    testWidgets('toggles the caret', (tester) async {
      final patches = await _rowsFor(tester, const {'type': 'Typewriter', 'text': 'T'});
      await tester.tap(find.byType(OiSwitch));
      expect(patches.single, {'caret': true});
    });
  });

  group('Markdown', () {
    testWidgets('edits the source and the reveal', (tester) async {
      final patches = await _rowsFor(tester, const {'type': 'Markdown', 'source': '# H'});
      await _commitField(tester, 0, '# Changed');
      expect(patches.single, {'source': '# Changed'});
      await _commitField(tester, 1, '2s');
      expect(patches.last, {'reveal': '2s'});
    });

    testWidgets('clearing the reveal removes the key', (tester) async {
      final patches = await _rowsFor(tester, const {
        'type': 'Markdown',
        'source': '# H',
        'reveal': '2s',
      });
      await _commitField(tester, 1, '');
      expect(patches.single, {'reveal': null});
    });
  });

  group('Terminal', () {
    testWidgets('edits prompt, typing speed, and line gap', (tester) async {
      final patches = await _rowsFor(tester, const {
        'type': 'Terminal',
        'lines': [
          {'cmd': 'ls'},
        ],
      });
      await _commitField(tester, 0, '> ');
      expect(patches.single, {'prompt': '> '});
      await _commitField(tester, 1, '1f');
      expect(patches.last, {'typingSpeed': '1f'});
      await _commitField(tester, 2, '5f');
      expect(patches.last, {'lineGap': '5f'});
    });
  });

  group('Code', () {
    testWidgets('edits the language and picks a theme', (tester) async {
      final patches = await _rowsFor(tester, const {
        'type': 'Code',
        'source': 'x',
        'language': 'dart',
      });
      await _commitField(tester, 0, 'js');
      expect(patches.single, {'language': 'js'});
      await _pickOption(tester, const ValueKey('style-code-theme'), 'dark');
      expect(patches.last, {'theme': 'dark'});
    });

    testWidgets('the default theme removes the key', (tester) async {
      final patches = await _rowsFor(tester, const {
        'type': 'Code',
        'source': 'x',
        'theme': 'dark',
      });
      await _pickOption(tester, const ValueKey('style-code-theme'), 'default');
      expect(patches.single, {'theme': null});
    });

    testWidgets('the reveal kind seeds its parameter and instant clears', (tester) async {
      final patches = await _rowsFor(tester, const {'type': 'Code', 'source': 'x'});
      await _pickOption(tester, const ValueKey('style-code-reveal'), 'typing');
      expect(patches.single, {
        'reveal': {'kind': 'typing', 'speed': '2f'},
      });

      final cleared = await _rowsFor(tester, const {
        'type': 'Code',
        'source': 'x',
        'reveal': {'kind': 'lineByLine', 'perLine': '18f'},
      });
      await _pickOption(tester, const ValueKey('style-code-reveal'), 'instant');
      expect(cleared.single, {'reveal': null});
    });

    testWidgets('a typing reveal exposes its speed as a time field', (tester) async {
      final patches = await _rowsFor(tester, const {
        'type': 'Code',
        'source': 'x',
        'reveal': {'kind': 'typing', 'speed': '2f'},
      });
      // Fields: language (0), then the reveal parameter (1).
      await _commitField(tester, 1, '4f');
      expect(patches.single, {
        'reveal': {'kind': 'typing', 'speed': '4f'},
      });
      // The codec requires the parameter: invalid and empty commits drop.
      await _commitField(tester, 1, 'nope');
      await _commitField(tester, 1, '');
      expect(patches, hasLength(1));
    });

    testWidgets('a lineByLine reveal exposes perLine', (tester) async {
      final patches = await _rowsFor(tester, const {
        'type': 'Code',
        'source': 'x',
        'reveal': {'kind': 'lineByLine', 'perLine': '18f'},
      });
      await _commitField(tester, 1, '9f');
      expect(patches.single, {
        'reveal': {'kind': 'lineByLine', 'perLine': '9f'},
      });
    });

    testWidgets('an instant reveal shows no parameter field', (tester) async {
      await _rowsFor(tester, const {'type': 'Code', 'source': 'x'});
      expect(find.byType(EditableText), findsOneWidget, reason: 'only the language field');
    });
  });

  group('Mermaid', () {
    testWidgets('picks the theme and the fit', (tester) async {
      final patches = await _rowsFor(tester, const {'type': 'Mermaid', 'source': 'graph TD;'});
      await _pickOption(tester, const ValueKey('style-mermaid-theme'), 'light');
      expect(patches.single, {'theme': 'light'});
      await _pickOption(tester, const ValueKey('style-fit'), 'cover');
      expect(patches.last, {'fit': 'cover'});
    });
  });

  group('WebView', () {
    testWidgets('edits the url and drops an invalid one', (tester) async {
      final patches = await _rowsFor(tester, const {
        'type': 'WebView',
        'uri': 'https://a.com',
        'viewport': {'width': 1280, 'height': 800},
      });
      await _commitField(tester, 0, 'https://b.com');
      expect(patches.single, {'uri': 'https://b.com'});
      await _commitField(tester, 0, 'not a url');
      expect(patches, hasLength(1));
    });

    testWidgets('edits the viewport sides as integers', (tester) async {
      final patches = await _rowsFor(tester, const {
        'type': 'WebView',
        'uri': 'https://a.com',
        'viewport': {'width': 1280, 'height': 800},
      });
      await _commitField(tester, 1, '640');
      expect(patches.single, {
        'viewport': {'width': 640, 'height': 800},
      });
    });
  });

  group('Html', () {
    testWidgets('edits the viewport height', (tester) async {
      final patches = await _rowsFor(tester, const {
        'type': 'Html',
        'source': '<b>x</b>',
        'viewport': {'width': 1280, 'height': 800},
      });
      await _commitField(tester, 1, '600');
      expect(patches.single, {
        'viewport': {'width': 1280, 'height': 600},
      });
    });
  });

  group('Bars', () {
    testWidgets('edits count, band, and gain', (tester) async {
      final patches = await _rowsFor(tester, const {'type': 'Bars'});
      await _commitField(tester, 0, '12');
      expect(patches.single, {'count': 12});
      await _pickOption(tester, const ValueKey('style-band'), 'treble');
      expect(patches.last, {'band': 'treble'});
      await _commitField(tester, 1, '2');
      expect(patches.last, {'gain': 2.0});
    });
  });

  group('LowerThird', () {
    testWidgets('edits name and title; an empty title clears it', (tester) async {
      final patches = await _rowsFor(tester, const {
        'type': 'LowerThird',
        'name': 'N',
        'title': 'T',
      });
      await _commitField(tester, 0, 'Ada');
      expect(patches.single, {'name': 'Ada'});
      await _commitField(tester, 1, '');
      expect(patches.last, {'title': null});
    });
  });

  group('TitleCard', () {
    testWidgets('edits title and subtitle', (tester) async {
      final patches = await _rowsFor(tester, const {
        'type': 'TitleCard',
        'title': 'T',
        'subtitle': 'S',
      });
      await _commitField(tester, 0, 'Big');
      expect(patches.single, {'title': 'Big'});
      await _commitField(tester, 1, '');
      expect(patches.last, {'subtitle': null});
    });
  });

  group('Snapshot', () {
    testWidgets('picks the fit with a contain default', (tester) async {
      final patches = await _rowsFor(tester, const {
        'type': 'Snapshot',
        'child': {'type': 'Text', 'text': 'S'},
      });
      final select = tester.widget<OiSelect<String>>(find.byKey(const ValueKey('style-fit')));
      expect(select.value, 'contain');
      await _pickOption(tester, const ValueKey('style-fit'), 'cover');
      expect(patches.single, {'fit': 'cover'});
    });
  });

  group('DeviceFrame', () {
    testWidgets('a phone toggles its notch', (tester) async {
      final patches = await _rowsFor(tester, const {
        'type': 'DeviceFrame',
        'variant': 'phone',
        'child': {'type': 'Text', 'text': 'F'},
      });
      await tester.tap(find.byType(OiSwitch));
      expect(patches.single, {'notch': false});
    });

    testWidgets('a browser edits its url', (tester) async {
      final patches = await _rowsFor(tester, const {
        'type': 'DeviceFrame',
        'variant': 'browser',
        'child': {'type': 'Text', 'text': 'F'},
      });
      await _commitField(tester, 0, 'fluvie.dev');
      expect(patches.single, {'url': 'fluvie.dev'});
    });

    testWidgets('switching the variant scrubs the other variants keys', (tester) async {
      final patches = await _rowsFor(tester, const {
        'type': 'DeviceFrame',
        'variant': 'phone',
        'notch': true,
        'child': {'type': 'Text', 'text': 'F'},
      });
      await _pickOption(tester, const ValueKey('style-variant'), 'tablet');
      expect(patches.single, {'variant': 'tablet', 'notch': null, 'url': null});
    });
  });

  group('Callout', () {
    testWidgets('edits the label', (tester) async {
      final patches = await _rowsFor(tester, const {
        'type': 'Callout',
        'label': 'Look',
        'target': {'x': 10, 'y': 10},
        'child': {'type': 'Box', 'color': '#00000000'},
      });
      await _commitField(tester, 0, 'Here');
      expect(patches.single, {'label': 'Here'});
    });
  });

  group('Spotlight', () {
    testWidgets('edits the reveal', (tester) async {
      final patches = await _rowsFor(tester, const {
        'type': 'Spotlight',
        'region': {'x': 0, 'y': 0, 'w': 10, 'h': 10},
        'child': {'type': 'Box', 'color': '#00000000'},
      });
      await _commitField(tester, 0, '1s');
      expect(patches.single, {'reveal': '1s'});
    });
  });
}
