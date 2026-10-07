import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show VideoSpec;
import 'package:fluvie/rendering.dart' show RenderCancellation;
import 'package:fluvie_editor/fluvie_editor.dart' show EditorCanvas, MediaImporter, MediaPick;
import 'package:slides/editor/deck_render_service.dart';
import 'package:slides/editor/slide_image_exporter.dart';
import 'package:slides/loader/fluvie_file_saver.dart';

// The end-to-end suite reuses the widget-journey deterministic fakes verbatim.
export '../test/desktop_surface.dart' show useDesktopSurface;
export '../test/memory_autosave_store.dart' show MemoryAutosaveStore;
export '../test/memory_recents_store.dart' show MemoryRecents;
export '../test/memory_start_prefs_store.dart' show MemoryStartPrefsStore;
export '../test/start_screen_robot.dart' show openDeckForEdit, openDemoForEdit, openSamples;

/// A saver that never touches the disk: every save cancels, so the deck
/// stays where it opened.
final class NeverSaver implements FluvieFileSaver {
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

/// A saver that records what the editor hands it and reports a fixed target,
/// so an export journey can read back the bytes the app produced.
final class RecordingSaver implements FluvieFileSaver {
  /// The byte-channel calls (PDF and bundle exports land here).
  final List<({String name, List<int> bytes})> bytesCalls = [];

  /// The source-copy calls (Dart export).
  final List<({String name, String contents})> copyCalls = [];

  /// What the byte channel returns; null simulates a cancelled dialog.
  String? nextBytesName = 'deck.pdf';

  @override
  String? targetPath;

  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
    bool pickNew = false,
  }) async => null;

  @override
  Future<String?> saveCopy({required String suggestedName, required String contents}) async {
    copyCalls.add((name: suggestedName, contents: contents));
    return suggestedName;
  }

  @override
  Future<String?> saveCopyBytes({required String suggestedName, required List<int> bytes}) async {
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

/// An importer standing in for a successful file pick (no OS dialog).
final class PickImporter implements MediaImporter {
  /// Creates an importer that always returns [pick].
  PickImporter(this.pick);

  /// The pick every call resolves to.
  final MediaPick pick;

  @override
  Future<MediaPick?> pickMedia() async => pick;
}

/// An image exporter that records the PNGs the editor renders and reports a
/// fixed folder, so an export journey never opens a real folder picker.
final class RecordingImageExporter implements SlideImageExporter {
  /// The saved batches (one entry per export).
  final List<({String baseName, List<Uint8List> images})> saved = [];

  @override
  Future<String?> saveImages({required String baseName, required List<Uint8List> images}) async {
    saved.add((baseName: baseName, images: images));
    return '/pics';
  }
}

/// A render service that reports itself unavailable, so an end-to-end run
/// never spawns a real encoder subprocess (the video path stays inert).
final class UnavailableRenderService implements DeckRenderService {
  @override
  bool get isAvailable => false;

  @override
  String get unavailableNote => 'needs the desktop app';

  @override
  Future<String?> renderToVideo({
    required VideoSpec spec,
    required String suggestedName,
    ExportOptions? options,
    RenderCancellation? cancellation,
    void Function(String phase)? onProgress,
  }) async => null;
}

/// Maps a point in canvas coordinates ([size], default 320x180) to a global
/// screen offset over the on-stage [EditorCanvas] — the same margin-48 fit the
/// canvas uses, so a `tapAt`/drag lands where the element renders.
Offset canvasAt(
  WidgetTester tester,
  Offset point, {
  Size size = const Size(320, 180),
}) {
  final canvas = tester.getRect(find.byType(EditorCanvas));
  const margin = 48.0;
  final scale = math.min(
    (canvas.width - 2 * margin) / size.width,
    (canvas.height - 2 * margin) / size.height,
  );
  final origin = canvas.center - Offset(size.width / 2 * scale, size.height / 2 * scale);
  return origin + point * scale;
}
