import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Box, LivePlayer, Placed;
import 'package:fluvie_editor/fluvie_editor.dart' show EditorCanvas, EditorDocument;
import 'package:fluvie_presenter/fluvie_presenter.dart' show FluvieSlides;
import 'package:obers_ui/obers_ui.dart' show OiApp, OiIconButton, OiIcons, OiThemeData;
import 'package:slides/editor/editor_screen.dart';
import 'package:slides/editor/session_media_store.dart';
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
      ],
    },
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
  testWidgets('edit a position, present it, and return with state intact', (tester) async {
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

    // Move the element one canvas pixel right.
    await tester.tapAt(_canvasAt(tester, const Offset(80, 90)));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('Unsaved'), findsOneWidget);

    await tester.tap(find.text('Present'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FluvieSlides), findsOneWidget);

    // The presented slide shows the element at its edited position: its
    // center sits at canvas (81, 90) mapped into the presenter's stage.
    final stage = tester.getRect(
      find.descendant(of: find.byType(FluvieSlides), matching: find.byType(LivePlayer)),
    );
    final scale = stage.width / 320;
    final expected = stage.topLeft + const Offset(81, 90) * scale;
    final placed = find.descendant(
      of: find.byType(FluvieSlides),
      matching: find.byWidgetPredicate((widget) => widget is Placed && widget.id == 'el-left'),
    );
    final box = find.descendant(of: placed, matching: find.byType(Box));
    expect((tester.getCenter(box) - expected).distance, lessThan(0.1));

    // Closing the presenter lands back in the editor, edits intact.
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
    expect(find.byType(EditorCanvas), findsOneWidget);
    // Present flushed the pending autosave, so the still-unsaved document
    // reports itself as covered.
    expect(find.text('Autosaved just now'), findsOneWidget);
  });

  testWidgets('presenting hands the speaker a session-rewritten payload', (tester) async {
    useDesktopSurface(tester);
    // A tiny valid PNG (1x1) so the live stages decode the session bytes.
    final photo = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );
    final session = SessionMediaStore(materialize: memorySessionMaterializer);
    addTearDown(session.clear);
    await session.adopt({'media/photo.png': photo});
    final deck = _deck();
    (((deck['scenes']! as List).first as Map<String, Object?>)['children']! as List).add({
      'id': 'el-img',
      'type': 'Image',
      'source': {'kind': 'bundle', 'value': 'media/photo.png'},
      'transform': {'x': 0.75, 'y': 0.5, 'w': 0.2, 'h': 0.2},
    });
    final stored = <({String kind, String payload})>[];
    await tester.pumpWidget(
      OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: EditorScreen(
          document: EditorDocument.fromJson(deck),
          title: 'mine.fluvie',
          onClose: () {},
          saver: _NeverSaver(),
          autosave: MemoryAutosaveStore(),
          sessionMedia: session,
          speakerMediaUrl: (value, bytes) => 'blob:test/$value',
          storeSpeaker: ({required kind, required payload}) =>
              stored.add((kind: kind, payload: payload)),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Present'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FluvieSlides), findsOneWidget);

    // The popup's copy carries the opener's session URLs, never a bundle
    // reference its own window could not resolve.
    final handed = stored.single;
    expect(handed.kind, 'file');
    final json = jsonDecode(handed.payload) as Map<String, Object?>;
    final children = ((json['scenes']! as List).first as Map<String, Object?>)['children']! as List;
    final image = children.last as Map<String, Object?>;
    expect(image['source'], {'kind': 'network', 'value': 'blob:test/media/photo.png'});
    // The rewrite is session-scoped: the document itself keeps its bundle ref.
    final document = tester.widget<EditorCanvas>(find.byType(EditorCanvas)).document;
    expect(document.elementJson('el-img')!['source'], {
      'kind': 'bundle',
      'value': 'media/photo.png',
    });
  });
}
