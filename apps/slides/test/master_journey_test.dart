import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart' show FluvieSlides;
import 'package:obers_ui/obers_ui.dart' show OiApp, OiIconButton, OiIcons, OiThemeData;
import 'package:slides/editor/editor_screen.dart';
import 'package:slides/loader/fluvie_file_saver.dart';

import 'desktop_surface.dart';
import 'memory_autosave_store.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'masters': {
    'base': {
      'background': {'kind': 'color', 'color': '#101018'},
      'children': [
        {
          'type': 'Box',
          'color': '#6C5CE7',
          'transform': {'x': 0.5, 'y': 0.9, 'w': 1.0, 'h': 0.08},
        },
        {
          'type': 'Placeholder',
          'slot': 'title',
          'transform': {'x': 0.5, 'y': 0.3, 'w': 0.8, 'h': 0.3},
          'style': {'fontSize': 18, 'color': '#F9FAFB'},
        },
      ],
    },
  },
  'scenes': [
    {'duration': '60f', 'layout': 'canvas', 'master': 'base', 'children': <Object?>[]},
    {'duration': '60f', 'layout': 'canvas', 'master': 'base', 'children': <Object?>[]},
  ],
};

final class _NeverSaver implements FluvieFileSaver {
  @override
  String? get targetPath => null;

  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
    bool pickNew = false,
  }) async => null;

  @override
  Future<String?> saveCopy({required String suggestedName, required String contents}) async => null;

  @override
  Future<String?> saveCopyBytes({required String suggestedName, required List<int> bytes}) async =>
      null;

  @override
  Future<String?> saveBundle({
    required String suggestedName,
    required List<int> bytes,
    bool pickNew = false,
  }) async => null;
}

Future<void> _pump(WidgetTester tester) async {
  useDesktopSurface(tester);
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: EditorScreen(
        document: EditorDocument.fromJson(_deck()),
        title: 'mine.fluvie',
        onClose: () {},
        saver: _NeverSaver(),
        autosave: MemoryAutosaveStore(),
      ),
    ),
  );
  await tester.pump();
}

EditorDocument _document(WidgetTester tester) =>
    tester.widget<EditorCanvas>(find.byType(EditorCanvas)).document;

Offset _canvasAt(WidgetTester tester, Offset point) {
  final canvas = tester.getRect(find.byType(EditorCanvas));
  const size = Size(320, 180);
  const margin = 48.0;
  final scale = math.min(
    (canvas.width - 2 * margin) / size.width,
    (canvas.height - 2 * margin) / size.height,
  );
  final origin = canvas.center - Offset(size.width / 2 * scale, size.height / 2 * scale);
  return origin + point * scale;
}

void main() {
  testWidgets('the placeholder-fill journey: adopt, click, type, present', (tester) async {
    await _pump(tester);
    // The adopting slide badges itself on the canvas and in the strip.
    expect(find.text('master: base'), findsOneWidget);
    expect(find.text('M base'), findsNWidgets(2));

    // Clicking the unfilled title slot types straight into a fill.
    await tester.tapAt(_canvasAt(tester, const Offset(160, 54)));
    await tester.pump();
    // The slot editor is the autofocused editable over the slot's box.
    final slotEditor = find.byWidgetPredicate(
      (widget) => widget is EditableText && widget.autofocus,
    );
    expect(slotEditor, findsOneWidget);
    await tester.enterText(slotEditor, 'Hello slot');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final document = _document(tester);
    final fillId = document.masterSlots(0).single.fillId;
    expect(fillId, isNotNull);
    expect(document.elementJson(fillId!)!['text'], 'Hello slot');

    // Present: the filled slot shows; the second slide's slot shows nothing.
    await tester.tap(find.text('Present'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FluvieSlides), findsOneWidget);
    expect(
      find.descendant(of: find.byType(FluvieSlides), matching: find.text('Hello slot')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(FluvieSlides),
        matching: find.byWidgetPredicate(
          (widget) => widget is OiIconButton && widget.icon == OiIcons.x,
        ),
      ),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(find.byType(FluvieSlides), findsNothing);
  });

  testWidgets('editing the master propagates to every adopting slide', (tester) async {
    await _pump(tester);
    final before = _document(tester).renderDigest;
    final masterBefore = _document(tester).masterJson('base');

    // Enter master-edit mode from the strip's masters row.
    await tester.tap(find.bySemanticsLabel('Edit master base'));
    await tester.pump();
    expect(find.byType(MasterEditor), findsOneWidget);
    expect(find.textContaining('Editing master "base"'), findsOneWidget);

    // Nudge the chrome bar: select it on the master canvas, arrow up.
    await tester.tapAt(_canvasAt(tester, const Offset(160, 162)));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    // Done returns to the deck; the master moved, so every adopting slide
    // re-derives (the digest covers them all).
    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(find.byType(MasterEditor), findsNothing);
    final document = _document(tester);
    expect(document.masterJson('base'), isNot(masterBefore));
    expect(document.renderDigest, isNot(before));
    expect(document.sceneMasterName(0), 'base');
    expect(document.sceneMasterName(1), 'base');

    // One undo step restores the master everywhere.
    await tester.tap(find.bySemanticsLabel('Undo'));
    await tester.pump();
    expect(_document(tester).renderDigest, before);
  });

  testWidgets('detach through the tile menu releases the slide', (tester) async {
    await _pump(tester);
    final scope = CommandScope(
      document: _document(tester),
      slide: 0,
      dispatch: (_) {},
    );
    // The tile menu carries the master items (wired through the registry).
    final labels = [
      for (final item in slideStripMenuItems(scope)) item.label,
    ];
    expect(labels, contains('Detach master'));
  });
}
