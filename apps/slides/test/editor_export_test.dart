// printVideoSpecJson is @experimental in fluvie_cli; the Dart export test
// pins the exported source to the printer's own output.
// ignore_for_file: experimental_member_use
import 'dart:async';
import 'dart:convert' show latin1;
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show VideoSpec;
import 'package:fluvie/rendering.dart' show RenderCancellation;
import 'package:fluvie_cli/codegen.dart' show printVideoSpecJson;
import 'package:fluvie_editor/fluvie_editor.dart' show EditorDocument;
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;
import 'package:slides/editor/deck_render_service.dart';
import 'package:slides/editor/editor_screen.dart';
import 'package:slides/editor/slide_image_exporter.dart';
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
          'id': 'el-box',
          'type': 'Box',
          'color': '#6C5CE7',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.4, 'h': 0.4},
        },
      ],
    },
    {
      'duration': '30f',
      'children': [
        {'id': 'el-text', 'type': 'Text', 'text': 'the second slide'},
      ],
    },
  ],
};

final class _FakeSaver implements FluvieFileSaver {
  final List<({String name, String contents, bool pickNew})> calls = [];
  final List<({String name, String contents})> copyCalls = [];
  final List<({String name, List<int> bytes})> bytesCalls = [];
  String? nextName = 'mine.fluvie';

  /// What saveCopyBytes returns (null simulates a cancelled dialog).
  String? nextBytesName = 'mine.pdf';

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
  Future<String?> saveCopyBytes({
    required String suggestedName,
    required List<int> bytes,
  }) async {
    bytesCalls.add((name: suggestedName, bytes: bytes));
    return nextBytesName;
  }

  @override
  Future<String?> saveBundle({
    required String suggestedName,
    required List<int> bytes,
    bool pickNew = false,
  }) async => null;
}

/// A renderer the test steers: it records the request, reports one phase,
/// then waits for [finish] to complete (with a path, null, or an error).
final class _FakeRenderService implements DeckRenderService {
  _FakeRenderService({this.available = true, this.note = 'needs the desktop app'});

  final bool available;
  final String note;
  final List<({Map<String, Object?> spec, String name})> requests = [];
  final Completer<String?> finish = Completer<String?>();

  @override
  bool get isAvailable => available;

  @override
  String get unavailableNote => note;

  @override
  Future<String?> renderToVideo({
    required VideoSpec spec,
    required String suggestedName,
    ExportOptions? options,
    RenderCancellation? cancellation,
    void Function(String phase)? onProgress,
  }) async {
    requests.add((spec: spec.toJson(), name: suggestedName));
    onProgress?.call('Capturing frames');
    return finish.future;
  }
}

final class _FakeImageExporter implements SlideImageExporter {
  final List<({String baseName, List<Uint8List> images})> saved = [];

  /// What saveImages returns (null simulates a cancelled folder pick).
  String? target = '/pics';

  /// Holds the platform write after it receives the PNGs, before completion.
  Completer<void>? writeGate;

  /// When set, saveImages throws instead (a failed write).
  Error? error;

  @override
  Future<String?> saveImages({required String baseName, required List<Uint8List> images}) async {
    if (error case final Error failure) throw failure;
    saved.add((baseName: baseName, images: images));
    if (writeGate case final gate?) await gate.future;
    return target;
  }
}

final class _Harness {
  _Harness(this.saver, this.render, this.images);
  final _FakeSaver saver;
  final _FakeRenderService render;
  final _FakeImageExporter images;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  bool renderAvailable = true,
  String renderNote = 'needs the desktop app',
}) async {
  useDesktopSurface(tester);
  final harness = _Harness(
    _FakeSaver(),
    _FakeRenderService(available: renderAvailable, note: renderNote),
    _FakeImageExporter(),
  );
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: EditorScreen(
        document: EditorDocument.fromJson(_deck()),
        title: 'mine.fluvie',
        onClose: () {},
        saver: harness.saver,
        render: harness.render,
        images: harness.images,
        autosave: MemoryAutosaveStore(),
      ),
    ),
  );
  await tester.pump();
  return harness;
}

Future<void> _openExportMenu(WidgetTester tester) async {
  await tester.tap(find.text('Export'));
  await tester.pumpAndSettle();
}

/// Opens the Export menu, picks the video entry, and confirms the options
/// dialog that now stands between the menu and the render seam.
///
/// The dialog opens on the deck's own resolution, quality and frame rate, so
/// confirming it unchanged is "export what I authored" and leaves the document
/// untouched.
Future<void> _startVideoExport(WidgetTester tester) async {
  await _openExportMenu(tester);
  await tester.tap(find.text('Export video (MP4)'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start export'));
  // Settles the dialog's pop: the export only resumes once that route is gone.
  await tester.pumpAndSettle();
  await tester.pump();
}

/// Pumps frames and drains real async work until [done] reads true — the
/// image export interleaves widget frames (the hidden render stage) with
/// engine read-backs (`toImage`/`toByteData`), so both loops need turns.
Future<void> _drain(WidgetTester tester, bool Function() done) async {
  // Raster read-back runs outside the fake clock: a fixed number of pumps can
  // finish before that work, especially while other suites use the rasterizer.
  // Stop on the observable result, with a wall timeout that fails explicitly.
  final elapsed = Stopwatch()..start();
  while (!done()) {
    if (elapsed.elapsed > const Duration(seconds: 10)) {
      fail('The expected export state did not arrive within 10 seconds.');
    }
    await tester.pump(const Duration(milliseconds: 16));
    // Yield one real event-loop turn for toImage/toByteData, without sleeping.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  await tester.pump();
}

void main() {
  testWidgets('the Export menu lists every flow', (tester) async {
    await _pump(tester);
    await _openExportMenu(tester);
    expect(find.text('Export .fluvie'), findsOneWidget);
    expect(find.text('Export Dart source'), findsOneWidget);
    expect(find.text('Export slide images (PNG)'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
    expect(find.text('Export video (MP4)'), findsOneWidget);
  });

  testWidgets('Export .fluvie is Save as under an export label', (tester) async {
    final harness = await _pump(tester);
    harness.saver.nextName = 'shared.fluvie';
    await _openExportMenu(tester);
    await tester.tap(find.text('Export .fluvie'));
    await tester.pumpAndSettle();
    expect(harness.saver.calls.single.pickNew, isTrue);
    // Save-as semantics: the document now points at the exported file.
    expect(find.text('shared.fluvie'), findsOneWidget);
  });

  testWidgets('Export Dart source writes the printed code through the copy channel', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await _openExportMenu(tester);
    await tester.tap(find.text('Export Dart source'));
    await tester.pumpAndSettle();

    final call = harness.saver.copyCalls.single;
    expect(call.name, 'mine.dart');
    expect(call.contents, printVideoSpecJson(_deck()));
    expect(call.contents, contains('Video build()'));
    // A source export never retargets the open document.
    expect(harness.saver.calls, isEmpty);
    expect(find.text('mine.fluvie'), findsOneWidget);
  });

  testWidgets('Export video runs the render seam with live progress', (tester) async {
    final harness = await _pump(tester);
    await _startVideoExport(tester);

    // The request carries the document's spec and a video name.
    final request = harness.render.requests.single;
    expect(request.name, 'mine.mp4');
    expect(request.spec['scenes'], hasLength(2));

    // The progress dialog shows the seam's live phase.
    expect(find.text('Capturing frames'), findsOneWidget);

    harness.render.finish.complete('/out/mine.mp4');
    await tester.pumpAndSettle();
    expect(find.text('Rendered to /out/mine.mp4'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Rendered to /out/mine.mp4'), findsNothing);
  });

  testWidgets('a changed frame rate rewrites the deck before the render', (tester) async {
    // fps is not a per-run override: a deck's timeline is measured in its own
    // frames, so capturing at another rate would pump a frame count the
    // composition does not have. The dialog therefore edits the document, and
    // the render sees the edited deck.
    final harness = await _pump(tester);
    await _openExportMenu(tester);
    await tester.tap(find.text('Export video (MP4)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('60'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start export'));
    await tester.pumpAndSettle();
    await tester.pump();

    expect(harness.render.requests.single.spec['fps'], 60);
  });

  testWidgets('confirming the dialog unchanged leaves the deck alone', (tester) async {
    final harness = await _pump(tester);
    await _startVideoExport(tester);

    expect(harness.render.requests.single.spec['fps'], 30);
  });

  testWidgets('a failing render surfaces its error', (tester) async {
    final harness = await _pump(tester);
    await _startVideoExport(tester);

    harness.render.finish.completeError(StateError('no ffmpeg on PATH'));
    await tester.pumpAndSettle();
    expect(find.textContaining('The render failed'), findsOneWidget);
    expect(find.textContaining('no ffmpeg on PATH'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.textContaining('The render failed'), findsNothing);
  });

  testWidgets('a cancelled output pick closes the progress dialog quietly', (tester) async {
    final harness = await _pump(tester);
    await _startVideoExport(tester);

    harness.render.finish.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Capturing frames'), findsNothing);
    expect(find.textContaining('Rendered to'), findsNothing);
  });

  testWidgets('without a desktop renderer the video item is disabled and says why', (
    tester,
  ) async {
    final harness = await _pump(tester, renderAvailable: false);
    await _openExportMenu(tester);
    expect(find.text('Export video (MP4)'), findsNothing);
    final item = find.text('Export video (needs the desktop app)');
    expect(item, findsOneWidget);
    await tester.tap(item);
    await tester.pumpAndSettle();
    expect(harness.render.requests, isEmpty);
  });

  testWidgets("the disabled entry carries the service's own reason", (tester) async {
    // The web service without the ffmpeg.wasm bridge names the bridge, not
    // the desktop app — the entry is honest per platform, never a dead button.
    await _pump(
      tester,
      renderAvailable: false,
      renderNote: 'needs the ffmpeg.wasm bridge in index.html',
    );
    await _openExportMenu(tester);
    expect(find.text('Export video (needs the ffmpeg.wasm bridge in index.html)'), findsOneWidget);
  });

  testWidgets('Export slide images renders every slide through the exporter', (tester) async {
    final harness = await _pump(tester);
    final writeGate = harness.images.writeGate = Completer<void>();
    addTearDown(() {
      if (!writeGate.isCompleted) writeGate.complete();
    });
    await _openExportMenu(tester);
    await tester.tap(find.text('Export slide images (PNG)'));
    await _drain(tester, () => harness.images.saved.isNotEmpty);

    final call = harness.images.saved.single;
    expect(call.baseName, 'mine');
    expect(call.images, hasLength(2));
    for (final png in call.images) {
      // Every artifact is a real PNG: the 8-byte signature leads.
      expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    }
    // Receiving the PNGs is earlier than the platform write completing. The
    // dialog must remain pending until that future settles, then rebuild Done.
    expect(find.text('Saved 2 images to /pics'), findsNothing);
    writeGate.complete();
    await _drain(tester, () => find.text('Saved 2 images to /pics').evaluate().isNotEmpty);
    expect(find.text('Saved 2 images to /pics'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Saved 2 images to /pics'), findsNothing);
  });

  testWidgets('Export PDF prints one page per slide through the copy-bytes channel', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await _openExportMenu(tester);
    await tester.tap(find.text('Export PDF'));
    await _drain(tester, () => find.text('Saved mine.pdf').evaluate().isNotEmpty);

    final call = harness.saver.bytesCalls.single;
    expect(call.name, 'mine.pdf');
    final text = latin1.decode(call.bytes);
    // A plausible PDF: the magic leads and the page tree counts one page
    // per slide.
    expect(text.startsWith('%PDF'), isTrue);
    expect(RegExp(r'/Count (\d+)').firstMatch(text)?.group(1), '2');
    // A byte export never retargets the open document.
    expect(harness.saver.calls, isEmpty);
    expect(find.text('Saved mine.pdf'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Saved mine.pdf'), findsNothing);
  });

  testWidgets('a cancelled PDF pick closes the progress dialog quietly', (tester) async {
    final harness = await _pump(tester);
    harness.saver.nextBytesName = null;
    await _openExportMenu(tester);
    await tester.tap(find.text('Export PDF'));
    await _drain(tester, () => harness.saver.bytesCalls.isNotEmpty);
    await tester.pumpAndSettle();
    expect(find.textContaining('Saved mine.pdf'), findsNothing);
    expect(find.textContaining('Rendering slide'), findsNothing);
    expect(find.textContaining('Building the PDF'), findsNothing);
  });

  testWidgets('an image export failure lands in the dialog', (tester) async {
    final harness = await _pump(tester);
    harness.images.error = StateError('disk full');
    await _openExportMenu(tester);
    await tester.tap(find.text('Export slide images (PNG)'));
    await _drain(
      tester,
      () => find.textContaining('The image export failed').evaluate().isNotEmpty,
    );
    expect(find.textContaining('disk full'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('a title without a fluvie extension exports under its own name', (tester) async {
    useDesktopSurface(tester);
    final harness = _Harness(_FakeSaver(), _FakeRenderService(), _FakeImageExporter());
    await tester.pumpWidget(
      OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: EditorScreen(
          document: EditorDocument.fromJson(_deck()),
          title: 'plain',
          onClose: () {},
          saver: harness.saver,
          render: harness.render,
          images: harness.images,
          autosave: MemoryAutosaveStore(),
        ),
      ),
    );
    await tester.pump();
    await _openExportMenu(tester);
    await tester.tap(find.text('Export Dart source'));
    await tester.pumpAndSettle();
    expect(harness.saver.copyCalls.single.name, 'plain.dart');
  });

  testWidgets('closing the deck mid-export aborts with a reason', (tester) async {
    final harness = await _pump(tester);
    await _openExportMenu(tester);
    await tester.tap(find.text('Export slide images (PNG)'));
    await tester.pump();

    // The deck closes while the first slide sits on the hidden stage. The
    // progress dialog is a route above the editor, so it outlives it and
    // has to say what happened.
    await tester.pumpWidget(
      OiApp(title: 'test', theme: OiThemeData.dark(), home: const SizedBox.shrink()),
    );
    await _drain(
      tester,
      () => find.textContaining('The image export failed').evaluate().isNotEmpty,
    );

    expect(find.textContaining('the deck closed'), findsOneWidget);
    expect(harness.images.saved, isEmpty, reason: 'a half-rendered deck is never written out');
  });

  testWidgets('a cancelled image export closes quietly', (tester) async {
    final harness = await _pump(tester);
    harness.images.target = null;
    await _openExportMenu(tester);
    await tester.tap(find.text('Export slide images (PNG)'));
    await _drain(tester, () => harness.images.saved.isNotEmpty);
    await tester.pumpAndSettle();
    expect(find.textContaining('Saved 2 images'), findsNothing);
    expect(find.textContaining('Rendering slide'), findsNothing);
  });
}
