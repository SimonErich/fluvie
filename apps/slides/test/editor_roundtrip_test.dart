import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart' show EditorCanvas;
import 'package:slides/editor/editor_screen.dart';
import 'package:slides/loader/fluvie_file_saver.dart';
import 'package:slides/loader/open_fluvie_file.dart';
import 'package:slides/loader/start_prefs_store.dart';
import 'package:slides/slides_app.dart';

import 'desktop_surface.dart';
import 'memory_autosave_store.dart';
import 'memory_start_prefs_store.dart';
import 'start_screen_robot.dart';

/// The tips card never gets in the way of an editor journey.
MemoryStartPrefsStore _prefs() => MemoryStartPrefsStore(const StartPrefs(tipsDismissed: true));

const _fixture =
    '{"fluvieSpec": 1, "size": {"width": 320, "height": 180}, "fps": 30, '
    '"scenes": [{"duration": "60f", "layout": "canvas", '
    '"background": {"kind": "color", "color": "#14141C"}, "children": [ '
    '{"id": "el-left", "type": "Box", "color": "#6C5CE7", '
    '"transform": {"x": 0.25, "y": 0.5, "w": 0.3, "h": 0.4}}]}]}';

final class _CapturingSaver implements FluvieFileSaver {
  String? contents;

  @override
  String? get targetPath => null;

  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
    bool pickNew = false,
  }) async {
    this.contents = contents;
    return suggestedName;
  }

  @override
  Future<String?> saveCopy({required String suggestedName, required String contents}) async {
    this.contents = contents;
    return suggestedName;
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

void main() {
  testWidgets('open, edit, save, reopen — only the edit changed', (tester) async {
    useDesktopSurface(tester);
    final saver = _CapturingSaver();
    await tester.pumpWidget(
      SlidesApp(
        openFile: () async => parseFluvieJson('mine.fluvie', saver.contents ?? _fixture),
        saver: saver,
        autosave: MemoryAutosaveStore(),
        startPrefs: _prefs(),
      ),
    );
    await tester.pump();

    // Open the fixture in Edit mode and move its element.
    await openDeckForEdit(tester);
    await tester.tapAt(_at(tester, const Offset(80, 90)));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    // Save, close, and reopen what was saved.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saver.contents, isNotNull);
    await tester.tap(find.bySemanticsLabel('Close editor'));
    await tester.pumpAndSettle();
    await openDeckForEdit(tester);

    final reopened = tester.widget<EditorScreen>(find.byType(EditorScreen)).document.toJson();
    final saved = jsonDecode(saver.contents!) as Map<String, Object?>;
    expect(reopened, saved);

    // Against the original, only the transform's x moved.
    final original = jsonDecode(_fixture) as Map<String, Object?>;
    Map<String, Object?> child(Map<String, Object?> doc) =>
        (((doc['scenes']! as List).first as Map<String, Object?>)['children']! as List).first
            as Map<String, Object?>;
    final movedTransform = child(reopened)['transform']! as Map<String, Object?>;
    expect(movedTransform['x'], closeTo(0.25 + 1 / 320, 1e-9));
    expect(movedTransform['y'], closeTo(0.5, 1e-9));
    child(reopened).remove('transform');
    child(original).remove('transform');
    expect(reopened, original);
  });
}
