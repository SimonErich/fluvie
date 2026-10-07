import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show EditableText;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart' show EditorCanvas, EditorDocument;
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;
import 'package:slides/editor/editor_screen.dart';
import 'package:slides/editor/renamable_title.dart';
import 'package:slides/loader/fluvie_file_saver.dart';

import 'desktop_surface.dart';
import 'memory_autosave_store.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'background': {'kind': 'color', 'color': '#14141C'},
      'children': [
        {
          'id': 'el-left',
          'type': 'Box',
          'color': '#6C5CE7',
          'transform': {'x': 0.25, 'y': 0.5, 'w': 0.3, 'h': 0.4},
        },
        {
          'id': 'el-right',
          'type': 'Box',
          'color': '#2ECC8F',
          'transform': {'x': 0.75, 'y': 0.5, 'w': 0.3, 'h': 0.4},
        },
      ],
    },
  ],
};

/// A saver that records what it was asked to write.
final class _FakeSaver implements FluvieFileSaver {
  final List<({String name, String contents, bool pickNew})> calls = [];
  final List<({String name, String contents})> copyCalls = [];

  /// What the next save returns (null simulates a cancelled dialog).
  String? nextName = 'mine.fluvie';

  /// What the remembered target reads as (a desktop path, null on the web).
  @override
  String? targetPath;

  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
    bool pickNew = false,
  }) async {
    calls.add((name: suggestedName, contents: contents, pickNew: pickNew));
    if (nextName != null) targetPath = '/decks/$nextName';
    return nextName;
  }

  @override
  Future<String?> saveCopy({required String suggestedName, required String contents}) async {
    copyCalls.add((name: suggestedName, contents: contents));
    return nextName;
  }

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

final class _Harness {
  _Harness(this.saver);
  final _FakeSaver saver;
  final List<(String, String?)> saved = [];
  final List<(String, String?)> renamed = [];
  int closed = 0;
}

Future<_Harness> _pump(WidgetTester tester, {Map<String, Object?>? deck}) async {
  useDesktopSurface(tester);
  final harness = _Harness(_FakeSaver());
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: EditorScreen(
        document: EditorDocument.fromJson(deck ?? _deck()),
        title: 'mine.fluvie',
        onClose: () => harness.closed++,
        saver: harness.saver,
        autosave: MemoryAutosaveStore(),
        onDeckSaved: (name, path) => harness.saved.add((name, path)),
        onDeckRenamed: (name, path) => harness.renamed.add((name, path)),
      ),
    ),
  );
  await tester.pump();
  return harness;
}

/// The screen point over canvas-pixel [point], replicating the canvas's
/// initial fit (`CanvasViewportController.fit`, margin 48).
Offset _at(WidgetTester tester, Offset point) {
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

Future<void> _selectLeftBox(WidgetTester tester) async {
  await tester.tapAt(_at(tester, const Offset(80, 90)));
  await tester.pump();
}

/// Opens the File menu, where Save as and Save a copy now live.
Future<void> _openFileMenu(WidgetTester tester) async {
  await tester.tap(find.text('File'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('save writes a document differing only by the edit', (tester) async {
    final harness = await _pump(tester);
    await _selectLeftBox(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(harness.saver.calls, hasLength(1));
    final saved = jsonDecode(harness.saver.calls.single.contents) as Map<String, Object?>;

    // Identity round-trip: reopening the saved text is the same document.
    expect(EditorDocument.fromJson(saved).toJson(), saved);

    // Only el-left's transform differs from the original.
    final original = _deck();
    final originalChild = ((original['scenes']! as List).first as Map)['children'] as List;
    final savedScene = (saved['scenes']! as List).first as Map<String, Object?>;
    final savedChildren = savedScene['children']! as List;
    final movedTransform =
        (savedChildren.first as Map<String, Object?>)['transform']! as Map<String, Object?>;
    expect(movedTransform['x'], closeTo(0.25 + 1 / 320, 1e-9));
    expect(movedTransform['y'], closeTo(0.5, 1e-9));
    expect(movedTransform['w'], closeTo(0.3, 1e-9));
    expect(movedTransform['h'], closeTo(0.4, 1e-9));
    // Neutralize the moved transform; everything else must match exactly.
    (savedChildren.first as Map<String, Object?>).remove('transform');
    (originalChild.first as Map<String, Object?>).remove('transform');
    expect(saved, original);
  });

  testWidgets('the saved indicator tracks edits and saves', (tester) async {
    await _pump(tester);
    expect(find.text('Saved'), findsOneWidget);

    await _selectLeftBox(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(find.text('Unsaved'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('a cancelled save stays unsaved', (tester) async {
    final harness = await _pump(tester);
    harness.saver.nextName = null;
    await _selectLeftBox(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved'), findsOneWidget);
  });

  testWidgets('Save as picks a new target and renames the title', (tester) async {
    final harness = await _pump(tester);
    harness.saver.nextName = 'renamed.fluvie';
    await _openFileMenu(tester);
    await tester.tap(find.text('Save as'));
    await tester.pumpAndSettle();
    expect(harness.saver.calls.single.pickNew, isTrue);
    expect(find.text('renamed.fluvie'), findsOneWidget);
  });

  testWidgets('closing clean leaves at once; dirty asks first', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Close editor'));
    await tester.pumpAndSettle();
    expect(harness.closed, 1);

    // Dirty: the guard blocks, Cancel stays, Discard leaves.
    await _selectLeftBox(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Close editor'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    expect(harness.closed, 1);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(harness.closed, 1);

    await tester.tap(find.bySemanticsLabel('Close editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(harness.closed, 2);
  });

  testWidgets('saving clears the dirty guard', (tester) async {
    final harness = await _pump(tester);
    await _selectLeftBox(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Close editor'));
    await tester.pumpAndSettle();
    expect(harness.closed, 1);
  });

  testWidgets('Save a copy writes elsewhere and never retargets the document', (tester) async {
    final harness = await _pump(tester);
    await _selectLeftBox(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(find.text('Unsaved'), findsOneWidget);

    harness.saver.nextName = 'copy.fluvie';
    await _openFileMenu(tester);
    await tester.tap(find.text('Save a copy'));
    await tester.pumpAndSettle();
    // The copy went through the copy channel, not the save channel.
    expect(harness.saver.copyCalls.single.name, 'mine.fluvie');
    expect(harness.saver.calls, isEmpty);
    // The open document is untouched: same title, still unsaved.
    expect(find.text('mine.fluvie'), findsOneWidget);
    expect(find.text('copy.fluvie'), findsNothing);
    expect(find.text('Unsaved'), findsOneWidget);
    // A copy is a background export; it never lands in recents.
    expect(harness.saved, isEmpty);

    // The next plain Save still goes to the original target.
    harness.saver.nextName = 'mine.fluvie';
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(harness.saver.calls.single.pickNew, isFalse);
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('a saved deck reports itself for the recents list', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(harness.saved.single, ('mine.fluvie', '/decks/mine.fluvie'));

    // A cancelled save reports nothing.
    harness.saver.nextName = null;
    await _openFileMenu(tester);
    await tester.tap(find.text('Save as'));
    await tester.pumpAndSettle();
    expect(harness.saved, hasLength(1));
  });

  testWidgets('a rename reports the new name against the saved target', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('mine.fluvie'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('mine.fluvie'));
    await tester.pump();
    final field = find.descendant(
      of: find.byType(RenamableTitle),
      matching: find.byType(EditableText),
    );
    await tester.enterText(field, 'deck.fluvie');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(harness.renamed.single, ('deck.fluvie', '/decks/mine.fluvie'));
    // The rename alone never dirties the document.
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('undo and redo drive the document from the top bar', (tester) async {
    await _pump(tester);
    await _selectLeftBox(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('Unsaved'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Undo'));
    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Redo'));
    await tester.pump();
    expect(find.text('Unsaved'), findsOneWidget);
  });
}
