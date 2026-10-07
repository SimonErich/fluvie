import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart' show PcmAudio;
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:slides/editor/editor_screen.dart';

import 'audio_preview_controller_test.dart' show FakeOutput, flush;
import 'desktop_surface.dart';
import 'memory_autosave_store.dart';

EditorDocument _document({bool audio = false}) => EditorDocument.fromJson({
  'fluvieSpec': 1,
  'fps': 30,
  'size': const {'width': 1280, 'height': 720},
  'scenes': const [
    {'duration': '2s', 'children': <Object?>[]},
  ],
  if (audio)
    'audio': const [
      {
        'kind': 'music',
        'source': {'kind': 'file', 'value': '/bed.wav'},
      },
    ],
  'editor': const {
    'editorSchema': 1,
    'deck': {'mode': 'video'},
    'media': [
      {
        'id': 'bed',
        'name': 'Source bed',
        'kind': 'audio',
        'source': {'kind': 'file', 'value': '/bed.wav'},
        'duration': '2s',
        'fps': 1000.0,
        'channels': 2,
      },
    ],
  },
});

Future<void> _open(WidgetTester tester, EditorDocument document, FakeOutput output) async {
  useDesktopSurface(tester);
  await tester.pumpWidget(
    OiApp(
      home: EditorScreen(
        document: document,
        title: 'Workspace workflows',
        onClose: () {},
        audioPreviewPlatform: output,
        autosave: MemoryAutosaveStore(),
      ),
    ),
  );
  await flush(tester);
}

Future<void> _workspace(WidgetTester tester, EditorWorkspace workspace) async {
  tester.widget<WorkspaceControl>(find.byType(WorkspaceControl)).onChanged(workspace);
  await flush(tester);
}

void main() {
  testWidgets('quality, draft and guide choices leave the authored project untouched', (
    tester,
  ) async {
    final document = _document();
    final original = document.toJson();
    await _open(tester, document, FakeOutput());
    EditorCanvas canvas() => tester.widget<EditorCanvas>(find.byType(EditorCanvas));
    expect(canvas().previewMaxEdge, 640);
    await tester.tap(find.text('Quarter'));
    await tester.pump();
    expect(canvas().previewMaxEdge, 320);
    await tester.tap(find.text('Full'));
    await tester.pump();
    expect(canvas().previewMaxEdge, isNull);
    await tester.tap(find.text('Effects on'));
    await tester.pump();
    expect(canvas().bypassEffects, isTrue);
    await _workspace(tester, EditorWorkspace.quick);
    expect(find.byType(QuickStartHint), findsOneWidget);
    await tester.tap(find.text('Dismiss guide'));
    await tester.pump();
    expect(find.byType(QuickStartHint), findsNothing);
    await _workspace(tester, EditorWorkspace.audio);
    expect(find.byType(AudioWorkspacePanel), findsOneWidget);
    await _workspace(tester, EditorWorkspace.edit);
    await tester.tap(find.text('Animation'));
    await tester.pump();
    expect(find.byType(AnimationPanel), findsOneWidget);
    expect(canvas().document.toJson(), original);
    expect(canvas().document.renderDigest, document.renderDigest);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('audio loading and decode failure recover through the visible retry action', (
    tester,
  ) async {
    final output = FakeOutput()..decodeGate = Completer<PcmAudio>();
    await _open(tester, _document(audio: true), output);
    expect(find.text('Preparing audio preview…'), findsOneWidget);
    output
      ..decodeGate!.completeError(StateError('Decoder unavailable'))
      ..decodeGate = null;
    await flush(tester);
    expect(find.textContaining('Audio preview unavailable:'), findsOneWidget);
    await tester.tap(find.text('Retry audio'));
    await flush(tester);
    expect(find.text('Retry audio'), findsNothing);
    expect(output.decoded, 2);
    await _workspace(tester, EditorWorkspace.audio);
    tester.widget<EditorCanvas>(find.byType(EditorCanvas)).transport!.seek(15);
    await flush(tester);
    expect(tester.widget<AudioWorkspacePanel>(find.byType(AudioWorkspacePanel)).currentFrame, 15);
    expect(
      tester.widget<AudioWorkspacePanel>(find.byType(AudioWorkspacePanel)).envelopes,
      isNotEmpty,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(output.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the source monitor starts and stops audition without placing media', (tester) async {
    final output = FakeOutput();
    final document = _document();
    await _open(tester, document, output);
    await tester.tap(find.text('Source bed'));
    await flush(tester);
    final listen = find.text('Listen from playhead');
    await tester.ensureVisible(listen);
    await tester.tap(listen);
    await flush(tester);
    expect(output.played, hasLength(1));
    expect(output.played.single, isA<Uint8List>());
    expect(find.text('Stop listening'), findsOneWidget);
    await tester.tap(find.text('Stop listening'));
    await flush(tester);
    expect(find.text('Listen from playhead'), findsOneWidget);
    expect(
      tester.widget<EditorCanvas>(find.byType(EditorCanvas)).document.toJson(),
      document.toJson(),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the title library inserts at the playhead and undoes its complete arrangement', (
    tester,
  ) async {
    final document = _document();
    await _open(tester, document, FakeOutput());
    tester.widget<EditorCanvas>(find.byType(EditorCanvas)).transport!.seek(15);
    await tester.tap(find.text('Titles'));
    await tester.pumpAndSettle();
    expect(tester.widget<TitlesPanel>(find.byType(TitlesPanel)).frame, 15);
    await tester.tap(find.text('Lower third'));
    await tester.pump();
    final edited = tester.widget<EditorCanvas>(find.byType(EditorCanvas)).document;
    expect(edited.elementIdsInScene(0), isNotEmpty);
    for (final id in edited.elementIdsInScene(0)) {
      expect(edited.elementJson(id)!['show'], {'from': '15f', 'to': '60f'});
    }
    expect(edited.themeJson, isNotNull);
    await tester.tap(find.bySemanticsLabel('Undo'));
    await tester.pump();
    expect(
      tester.widget<EditorCanvas>(find.byType(EditorCanvas)).document.toJson(),
      document.toJson(),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('slide colour controls resolve element and global progress on the absolute clock', (
    tester,
  ) async {
    final document = EditorDocument.fromJson(const {
      'fluvieSpec': 1,
      'fps': 30,
      'scenes': [
        {'duration': '30f', 'children': <Object?>[]},
        {
          'duration': '90f',
          'children': [
            {
              'id': 'window',
              'type': 'Box',
              'color': '#112233',
              'show': {'from': '10f', 'to': '40f'},
            },
            {'id': 'bare', 'type': 'Box', 'color': '#445566'},
          ],
        },
      ],
      'overlays': [
        {'id': 'global', 'type': 'Box', 'color': '#778899'},
      ],
    });
    await _open(tester, document, FakeOutput());
    await tester.tap(find.bySemanticsLabel('Next slide'));
    await tester.pump();
    tester.widget<EditorCanvas>(find.byType(EditorCanvas)).transport!.seek(25);
    await _workspace(tester, EditorWorkspace.colour);
    final progress = tester.widget<ColourPanel>(find.byType(ColourPanel)).playheadProgress!;
    expect(progress('window'), .5);
    expect(progress('bare'), closeTo(25 / 90, 1e-10));
    expect(progress('global'), closeTo(55 / 120, 1e-10));
    expect(
      tester.widget<EditorCanvas>(find.byType(EditorCanvas)).document.toJson(),
      document.toJson(),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
