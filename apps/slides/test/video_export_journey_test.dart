import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show VideoSpec;
import 'package:fluvie/rendering.dart'
    show MemoryRenderSandbox, resolveAudioMix, stageResolvedAudioToSandbox;
import 'package:fluvie/rendering.dart' show RenderCancellation;
import 'package:fluvie_editor/fluvie_editor.dart'
    show
        AudioTrackSection,
        EditorCanvas,
        EditorDocument,
        EditorDocumentAudio,
        EditorDocumentMedia,
        MediaImporter,
        MediaPick,
        MediaStoreKind,
        TrackTimeline;
import 'package:obers_ui/obers_ui.dart' show OiApp, OiSelect, OiThemeData;
import 'package:slides/editor/deck_render_service.dart';
import 'package:slides/editor/editor_screen.dart';
import 'package:slides/editor/file_media_importer.dart';
import 'package:slides/loader/fluvie_file_saver.dart';

import 'desktop_surface.dart';
import 'memory_autosave_store.dart';

// The 9.6 export journey: import media, arrange two clip lanes and two audio
// tracks in video mode, export, and prove the render service received the
// spec-built Video whose audio mix plan carries both tracks — the FFmpeg
// arg/filter graph is the pin, never encoded bytes.

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {'duration': '90f', 'layout': 'canvas', 'children': <Object?>[]},
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

/// Serves one queued pick per M-key import, like a user picking files.
final class _QueueImporter implements MediaImporter {
  _QueueImporter(this.picks);
  final List<MediaPick> picks;
  int _next = 0;

  @override
  Future<MediaPick?> pickMedia() async => _next < picks.length ? picks[_next++] : null;
}

/// Records the export request; the spec object stays inspectable.
final class _FakeRenderService implements DeckRenderService {
  final List<({VideoSpec spec, String name})> requests = [];
  final Completer<String?> finish = Completer<String?>();

  @override
  bool get isAvailable => true;

  @override
  String get unavailableNote => 'always available in this fake';

  @override
  Future<String?> renderToVideo({
    required VideoSpec spec,
    required String suggestedName,
    ExportOptions? options,
    RenderCancellation? cancellation,
    void Function(String phase)? onProgress,
  }) async {
    requests.add((spec: spec, name: suggestedName));
    return finish.future;
  }
}

final class _Harness {
  _Harness(this.render);
  final _FakeRenderService render;

  EditorDocument documentOf(WidgetTester tester) =>
      tester.widget<EditorCanvas>(find.byType(EditorCanvas)).document;
}

Future<_Harness> _pump(WidgetTester tester, List<MediaPick> picks) async {
  useDesktopSurface(tester);
  final harness = _Harness(_FakeRenderService());
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: EditorScreen(
        document: EditorDocument.fromJson(_deck()),
        title: 'journey.fluvie',
        onClose: () {},
        saver: _NeverSaver(),
        importer: _QueueImporter(picks),
        render: harness.render,
        autosave: MemoryAutosaveStore(),
      ),
    ),
  );
  await tester.pump();
  return harness;
}

Future<void> _import(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
  await tester.pumpAndSettle();
}

Future<void> _tapLabel(WidgetTester tester, String semanticLabel) async {
  await tester.tap(find.bySemanticsLabel(semanticLabel));
  await tester.pump();
  await tester.pump();
}

/// The lanes origin inside the video timeline: the labels column (140) plus
/// the ruler strip (24). The panel zooms at 2 px per frame.
Offset _lanesOrigin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(TrackTimeline)) + const Offset(140, 24);

Offset _row(WidgetTester tester, int row, double x) =>
    _lanesOrigin(tester) + Offset(x, row * 28 + 14);

Future<void> _drag(WidgetTester tester, Offset from, Offset by) async {
  final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  await gesture.moveBy(Offset(by.dx / 2, 0));
  await tester.pump();
  await gesture.moveBy(Offset(by.dx / 2, 0));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

Finder _input(String key) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(EditableText));

Future<void> _commit(WidgetTester tester, String key, String text) async {
  await tester.enterText(_input(key), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  testWidgets('the video-mode export journey: import, arrange, export, and the mix plan', (
    tester,
  ) async {
    final harness = await _pump(tester, [
      (await mediaPickFor(name: 'clip.mp4', path: '/abs/clip.mp4'))!,
      (await mediaPickFor(name: 'broll.mp4', path: '/abs/broll.mp4'))!,
      (await mediaPickFor(name: 'bed.mp3', path: '/abs/bed.mp3'))!,
    ]);

    // Import two videos (clips on the canvas) and one audio (store-only).
    await _import(tester);
    await _import(tester);
    await _import(tester);
    var document = harness.documentOf(tester);
    final clipIds = document.elementIdsInScene(0);
    expect(clipIds, hasLength(2));
    expect(document.mediaEntries, hasLength(3));
    final bedEntry = document.mediaEntries.firstWhere(
      (entry) => entry.kind == MediaStoreKind.audio,
    );
    expect(bedEntry.name, 'bed.mp3');

    // Enter video mode: two clip lanes appear (topmost first: broll, clip).
    await _tapLabel(tester, 'Video mode');
    expect(find.text('broll.mp4'), findsWidgets);
    final brollId = clipIds[1];
    final clipId = clipIds[0];

    // Trim the topmost clip's right edge: the whole 90f scene minus 20
    // frames (40 px) mints its first show window, one undoable step.
    await _drag(tester, _row(tester, 1, 178), const Offset(-40, 0));
    document = harness.documentOf(tester);
    expect(document.elementJson(brollId)!['show'], {'from': '0f', 'to': '70f'});
    await _tapLabel(tester, 'Undo');
    expect(harness.documentOf(tester).elementJson(brollId)!.containsKey('show'), isFalse);
    await _tapLabel(tester, 'Redo');
    expect(harness.documentOf(tester).elementJson(brollId)!['show'], {'from': '0f', 'to': '70f'});

    // Move the trimmed window 10 frames later (20 px).
    await _drag(tester, _row(tester, 1, 70), const Offset(20, 0));
    expect(harness.documentOf(tester).elementJson(brollId)!['show'], {
      'from': '10f',
      'to': '80f',
    });

    // Trim the second clip lane to 80f.
    await _drag(tester, _row(tester, 2, 178), const Offset(-20, 0));
    expect(harness.documentOf(tester).elementJson(clipId)!['show'], {'from': '0f', 'to': '80f'});

    // Add the imported bed twice through the picker: two music tracks,
    // each add its own undoable step.
    final select = tester.widget<OiSelect<String>>(find.byKey(const ValueKey('video-add-audio')));
    select.onChanged!(bedEntry.id);
    await tester.pump();
    select.onChanged!(bedEntry.id);
    await tester.pump();
    document = harness.documentOf(tester);
    expect(document.audioTracksJson(), hasLength(2));
    await _tapLabel(tester, 'Undo');
    expect(harness.documentOf(tester).audioTracksJson(), hasLength(1));
    await _tapLabel(tester, 'Redo');
    expect(harness.documentOf(tester).audioTracksJson(), hasLength(2));

    // Author the mix through the audio inspector: lane rows 3 and 4.
    await tester.tapAt(_row(tester, 3, 100));
    await tester.pump();
    expect(find.byType(AudioTrackSection), findsOneWidget);
    await _commit(tester, 'audio-volume', '0.6');
    await _commit(tester, 'audio-fade-in', '12');
    await tester.tapAt(_row(tester, 4, 100));
    await tester.pump();
    await _commit(tester, 'audio-volume', '0.3');
    document = harness.documentOf(tester);
    expect(document.audioTracksJson()[0]['volume'], 0.6);
    expect(document.audioTracksJson()[0]['fadeIn'], '12f');
    expect(document.audioTracksJson()[1]['volume'], 0.3);

    // Export through the 8.4 menu, then confirm the options dialog it opens.
    // Confirming it unchanged is "export what I authored": the dialog reads the
    // deck's own resolution, quality and frame rate.
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export video (MP4)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start export'));
    await tester.pumpAndSettle();
    await tester.pump();
    final request = harness.render.requests.single;
    expect(request.name, 'journey.mp4');
    harness.render.finish.complete('/out/journey.mp4');
    await tester.pumpAndSettle();
    expect(find.text('Rendered to /out/journey.mp4'), findsOneWidget);

    // The received spec builds the same Video either platform renders: both
    // clips windowed, both authored audio tracks on it.
    final specJson = request.spec.toJson();
    final children =
        ((specJson['scenes']! as List).first! as Map<String, Object?>)['children']! as List;
    final sources = {
      for (final child in children.cast<Map<String, Object?>>())
        (child['source']! as Map<String, Object?>)['value']: child['show'],
    };
    expect(sources['/abs/broll.mp4'], {'from': '10f', 'to': '80f'});
    expect(sources['/abs/clip.mp4'], {'from': '0f', 'to': '80f'});

    final video = request.spec.build();
    expect(video.audio, hasLength(2));
    expect(video.audio[0].source, '/abs/bed.mp3');
    expect(video.audio[0].volume, 0.6);
    expect(video.audio[1].volume, 0.3);

    // The guardrail: pin the FFmpeg mix plan, not encoded bytes. The two
    // declared tracks lead the mix (clip-embedded audio follows) and the
    // authored volume and fade reach the filter graph verbatim.
    final mix = resolveAudioMix(video: video, fps: 30, totalFrames: video.totalFrames);
    expect(mix.tracks, hasLength(4)); // 2 declared beds + 2 clip audio arms
    expect(mix.tracks[0].volume, 0.6);
    expect(mix.tracks[0].fadeInSeconds, 0.4); // 12f at 30 fps
    expect(mix.tracks[1].volume, 0.3);

    final sandbox = MemoryRenderSandbox();
    final plan = await stageResolvedAudioToSandbox(
      tracks: mix.tracks,
      sandbox: sandbox,
      loadBytes: (source) async => Uint8List.fromList(utf8.encode(source)),
    );
    final labels = [for (var i = 0; i < plan.tracks.length; i++) 'a$i'];
    final graph = [
      for (var i = 0; i < plan.tracks.length; i++)
        plan.tracks[i].filterChain(inputIndex: i + 1, label: labels[i]),
      plan.amix!.mixChain(labels: labels, outLabel: 'aout'),
    ].join(';');
    expect(plan.tracks[0].inputArgs(), contains('-i'));
    expect(plan.tracks[0].name, startsWith('audio_0_'));
    expect(plan.tracks[1].name, startsWith('audio_1_'));
    expect(graph, contains('volume=0.6'));
    expect(graph, contains('afade=t=in:st=0:d=0.4'));
    expect(graph, contains('volume=0.3'));
    expect(graph, contains('amix=inputs=4:normalize=0'));
    // Both staged inputs really landed in the sandbox for the encoder to -i.
    expect(await sandbox.readBytes(plan.tracks[0].name), utf8.encode('/abs/bed.mp3'));
    expect(await sandbox.readBytes(plan.tracks[1].name), utf8.encode('/abs/bed.mp3'));
  });
}
