import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show CubeLut, VideoSpec;
import 'package:fluvie/rendering.dart' show RenderCancellation;
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:slides/editor/deck_render_service.dart';
import 'package:slides/editor/editor_screen.dart';

import 'audio_preview_controller_test.dart' show FakeOutput, flush;
import 'desktop_surface.dart';
import 'memory_autosave_store.dart';

final class _Renderer implements DeckRenderService {
  final requests =
      <
        ({
          String name,
          VideoSpec spec,
          ExportOptions? options,
          RenderCancellation cancel,
          Completer<String?> done,
        })
      >[];
  @override
  bool get isAvailable => true;
  @override
  String get unavailableNote => '';
  @override
  Future<String?> renderToVideo({
    required VideoSpec spec,
    required String suggestedName,
    ExportOptions? options,
    RenderCancellation? cancellation,
    void Function(String)? onProgress,
  }) {
    final done = Completer<String?>();
    requests.add((
      name: suggestedName,
      spec: spec,
      options: options,
      cancel: cancellation!,
      done: done,
    ));
    onProgress?.call('Capturing preview');
    return done.future;
  }
}

EditorDocument _document() => EditorDocument.fromJson(const {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {'id': 'box', 'type': 'Box'},
      ],
    },
  ],
});
Future<void> _open(WidgetTester tester, _Renderer render, EditorWorkspace workspace) async {
  useDesktopSurface(tester);
  await tester.pumpWidget(
    OiApp(
      home: EditorScreen(
        document: _document(),
        title: 'Delivery test',
        onClose: () {},
        render: render,
        audioPreviewPlatform: FakeOutput(),
        autosave: MemoryAutosaveStore(),
      ),
    ),
  );
  await flush(tester);
  tester.widget<WorkspaceControl>(find.byType(WorkspaceControl)).onChanged(workspace);
  await flush(tester);
}

void main() {
  testWidgets(
    'batch delivery holds snapshots, cancels queued work and acknowledges running cleanup',
    (tester) async {
      final render = _Renderer();
      await _open(tester, render, EditorWorkspace.deliver);
      final canvas = tester.widget<EditorCanvas>(find.byType(EditorCanvas));
      final original = canvas.document.renderDigest;
      await tester.tap(find.text('Batch 1080p + 720p'));
      await tester.pump(const Duration(milliseconds: 1));
      await flush(tester);
      expect(render.requests, hasLength(1));
      expect(render.requests.single.name, endsWith('-1080p.mp4'));
      expect(render.requests.single.options!.longEdge, 1920);
      expect(find.text('Cancel 2'), findsOneWidget);
      canvas.onCommand!(
        ReplaceElementCommand(
          id: 'box',
          element: {...canvas.document.elementJson('box')!, 'color': '#ff0000'},
        ),
      );
      await flush(tester);
      expect(render.requests.single.spec.digest(), original);
      expect(
        tester.widget<EditorCanvas>(find.byType(EditorCanvas)).document.renderDigest,
        isNot(original),
      );
      await tester.tap(find.text('Cancel 2'));
      await flush(tester);
      expect(find.textContaining('Cancelled before rendering'), findsOneWidget);
      await tester.tap(find.text('Cancel 1'));
      await flush(tester);
      expect(render.requests.single.cancel.isCancelled, isTrue);
      expect(find.textContaining('Cancelling and cleaning'), findsOneWidget);
      render.requests.single.done.complete(null);
      await flush(tester);
      expect(render.requests, hasLength(1));
      expect(find.textContaining('Temporary render files removed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('LUT picker cancellation, portable input and four MiB bound use one contract', (
    tester,
  ) async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
    Uint8List? bytes;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'custom');
      expect((call.arguments as Map<Object?, Object?>)['allowedExtensions'], ['cube']);
      expect((call.arguments as Map<Object?, Object?>)['withData'], isTrue);
      return bytes == null
          ? null
          : [
              {'name': 'look.cube', 'size': bytes.length, 'bytes': bytes},
            ];
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await _open(tester, _Renderer(), EditorWorkspace.colour);
    final import = tester.widget<ColourPanel>(find.byType(ColourPanel)).onImportLut!;
    expect(await import(), isNull);
    final cube = colourLooks.last.effects.single['cube']! as String;
    bytes = Uint8List.fromList(utf8.encode(cube));
    expect(await import(), cube);
    final valid = CubeLut.parse(cube);
    expect(valid.size, greaterThan(1));
    final atLimit = '$cube\n#'.padRight(4 * 1024 * 1024);
    bytes = Uint8List.fromList(utf8.encode(atLimit));
    final importedLimit = await import();
    expect(importedLimit, hasLength(4 * 1024 * 1024));
    expect(CubeLut.parse(importedLimit!).size, valid.size);
    bytes = Uint8List(4 * 1024 * 1024 + 1);
    await expectLater(
      import(),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('4 MiB'))),
    );
    expect(
      tester.widget<EditorCanvas>(find.byType(EditorCanvas)).document.renderDigest,
      _document().renderDigest,
    );
    expect(tester.takeException(), isNull);
  });
}
