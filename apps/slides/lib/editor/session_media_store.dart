import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:fluvie/fluvie.dart' show AudioSource, BundleMedia, MediaSource;
import 'package:slides/editor/file_media_importer.dart';
import 'package:slides/editor/session_media_io.dart'
    if (dart.library.js_interop) 'package:slides/editor/session_media_web.dart';
import 'package:slides/editor/session_sources.dart';

export 'package:slides/editor/session_sources.dart';

/// The default session byte budget (256 MiB).
const int defaultSessionMediaBudget = 256 << 20;

/// An import past the session byte budget — refused with this visible error,
/// never silently dropped.
final class SessionMediaBudgetError implements Exception {
  /// Creates the refusal for a file of [attemptedBytes] against [heldBytes]
  /// already held under [budgetBytes].
  const SessionMediaBudgetError({
    required this.attemptedBytes,
    required this.heldBytes,
    required this.budgetBytes,
  });

  /// The refused file's size.
  final int attemptedBytes;

  /// The bytes the session already holds.
  final int heldBytes;

  /// The session's budget.
  final int budgetBytes;

  @override
  String toString() =>
      'SessionMediaBudgetError: a $attemptedBytes-byte import would push the '
      'session past its $budgetBytes-byte media budget ($heldBytes held)';
}

/// The media bytes of the open editing session, keyed by bundle-relative
/// value (`media/<name>`).
///
/// Web imports and opened bundles live here: [register] takes one imported
/// file, [adopt] a whole unpacked bundle. Every change re-publishes
/// [BundleMedia.current], so `bundle` sources in the document resolve for as
/// long as the session holds their bytes; a bundle save reads [bytes] back.
/// The held total is bounded by [budgetBytes]; an import past it throws a
/// [SessionMediaBudgetError].
final class SessionMediaStore {
  /// Creates the store over [budgetBytes] and a [materialize] seam (the
  /// platform default: temp files on desktop, memory on the web).
  SessionMediaStore({
    this.budgetBytes = defaultSessionMediaBudget,
    SessionMaterializer? materialize,
  }) : _materialize = materialize ?? platformSessionMaterializer();

  /// The most bytes the session holds at once.
  final int budgetBytes;

  final SessionMaterializer _materialize;
  final Map<String, Uint8List> _bytes = {};
  final Map<String, SessionSources> _sources = {};

  /// The bytes held per bundle-relative value — what a bundle save packs.
  Map<String, Uint8List> get bytes => Map.unmodifiable(_bytes);

  /// The bytes held under [value], or null.
  Uint8List? bytesFor(String value) => _bytes[value];

  /// The total bytes the session holds.
  int get heldBytes => _bytes.values.fold(0, (sum, held) => sum + held.length);

  /// Registers one imported file, returning its bundle-relative value
  /// (`media/<name>`, numbered on a name clash). Re-registering identical
  /// content under the same name reuses the held entry, so values — and the
  /// document digest — stay stable. Throws a [SessionMediaBudgetError] past
  /// [budgetBytes].
  Future<String> register(String name, Uint8List bytes) async {
    final base = _fileName(name);
    var candidate = 'media/$base';
    for (var n = 2; _bytes.containsKey(candidate); n++) {
      if (listEquals(_bytes[candidate], bytes)) return candidate;
      candidate = 'media/${_numbered(base, n)}';
    }
    if (heldBytes + bytes.length > budgetBytes) {
      throw SessionMediaBudgetError(
        attemptedBytes: bytes.length,
        heldBytes: heldBytes,
        budgetBytes: budgetBytes,
      );
    }
    await _hold(candidate, bytes);
    return candidate;
  }

  /// Adopts a whole unpacked bundle verbatim: every entry under its exact
  /// value, so reopened documents resolve unchanged. An entry identical to
  /// one already held is free (a crash recovery adopts over the reopened
  /// bundle's own media), and replacing an entry counts only the size
  /// delta. Throws a [SessionMediaBudgetError] past [budgetBytes].
  Future<void> adopt(Map<String, Uint8List> media) async {
    for (final entry in media.entries) {
      final held = _bytes[entry.key];
      if (held != null && listEquals(held, entry.value)) continue;
      if (heldBytes - (held?.length ?? 0) + entry.value.length > budgetBytes) {
        throw SessionMediaBudgetError(
          attemptedBytes: entry.value.length,
          heldBytes: heldBytes,
          budgetBytes: budgetBytes,
        );
      }
      await _hold(entry.key, entry.value);
    }
  }

  /// Empties the session and retires the published bundle scope (the open
  /// document closed).
  void clear() {
    _bytes.clear();
    _sources.clear();
    BundleMedia.current = null;
  }

  /// The bundle context over everything held: audio files in the audio map,
  /// everything else in the media map.
  BundleMedia bundleMedia() {
    final media = <String, MediaSource>{};
    final audio = <String, AudioSource>{};
    _sources.forEach((value, sources) {
      if (isAudioName(value)) {
        audio[value] = sources.audio;
      } else {
        media[value] = sources.media;
      }
    });
    return BundleMedia(media: media, audio: audio);
  }

  Future<void> _hold(String value, Uint8List bytes) async {
    _bytes[value] = bytes;
    _sources[value] = await _materialize(value, bytes);
    BundleMedia.current = bundleMedia();
  }

  static String _fileName(String name) {
    final segments = name.split(RegExp(r'[\\/]')).where((part) => part.isNotEmpty);
    return segments.isEmpty ? 'file' : segments.last;
  }

  static String _numbered(String base, int n) {
    final dot = base.lastIndexOf('.');
    return dot <= 0 ? '$base-$n' : '${base.substring(0, dot)}-$n${base.substring(dot)}';
  }
}

/// The one session the running app holds (one document open at a time);
/// tests construct their own stores instead.
final SessionMediaStore sessionMediaStore = SessionMediaStore();
