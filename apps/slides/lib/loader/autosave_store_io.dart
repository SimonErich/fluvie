import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:slides/loader/autosave_record.dart';
import 'package:slides/loader/autosave_store.dart';
import 'package:slides/loader/fluvie_bundle.dart';

/// The desktop autosave store.
AutosaveStore platformAutosaveStore() => IoAutosaveStore();

/// The sidecar file name for a deck [key] (a target path or a deck name):
/// FNV-1a-64 hex over the key, so any path or name maps to a fixed-shape,
/// filesystem-safe name. This io-only store runs on the VM, whose 64-bit
/// wrapping arithmetic the hash relies on (the basis is split into two
/// 32-bit halves to avoid an unsigned 64-bit literal).
String autosaveFileName(String key) {
  var hash = (0xcbf29ce4 << 32) | 0x84222325;
  for (final unit in key.codeUnits) {
    hash = (hash ^ unit) * 0x100000001b3;
  }
  final high = (hash >> 32) & 0xffffffff;
  final low = hash & 0xffffffff;
  final hex = high.toRadixString(16).padLeft(8, '0') + low.toRadixString(16).padLeft(8, '0');
  return '$hex.json';
}

/// Desktop autosaves: one sidecar per deck under the user's config directory
/// (`$XDG_CONFIG_HOME`, falling back to `$HOME/.config`) — never next to the
/// user's own file.
///
/// The sidecar takes the `.fluvie` file's own dual form: a record covering
/// session media is written as a bundle zip (the record JSON as the deck
/// entry, the bytes under `media/`), anything else as plain record JSON.
/// Reads sniff the first bytes exactly like an open, so recovery restores a
/// crashed session-media deck whole — bytes, previews, and all.
final class IoAutosaveStore implements AutosaveStore {
  /// Creates the store over [directory]; without one, the default
  /// config-directory location derived from [environment] (the process
  /// environment).
  IoAutosaveStore({String? directory, Map<String, String>? environment})
    : directory = directory ?? _defaultDirectory(environment ?? Platform.environment);

  /// Where the sidecars live.
  final String directory;

  static String _defaultDirectory(Map<String, String> environment) {
    final base = environment['XDG_CONFIG_HOME'] ?? '${environment['HOME'] ?? '.'}/.config';
    return '$base/fluvie_slides/autosave';
  }

  /// The sidecar path for [key].
  String pathFor(String key) => '$directory/${autosaveFileName(key)}';

  @override
  Future<AutosaveSnapshot?> read(String key) async {
    final Uint8List bytes;
    try {
      bytes = await File(pathFor(key)).readAsBytes();
    } on IOException {
      return null;
    }
    try {
      if (!isZipBytes(bytes)) {
        final record = decodeAutosaveRecord(utf8.decode(bytes));
        return record == null ? null : (record: record, media: const <String, Uint8List>{});
      }
      final bundle = readFluvieBundle(bytes);
      final record = decodeAutosaveRecord(bundle.deckJson);
      return record == null ? null : (record: record, media: bundle.media);
    } on Object {
      // A corrupt sidecar (of either form) reads as absent, never a throw.
      return null;
    }
  }

  @override
  Future<void> write(
    String key,
    AutosaveRecord record, {
    Map<String, Uint8List> media = const {},
  }) async {
    try {
      final file = File(pathFor(key));
      await file.parent.create(recursive: true);
      if (media.isEmpty) {
        await file.writeAsString(encodeAutosaveRecord(record));
      } else {
        await file.writeAsBytes(
          buildFluvieBundle(deckJson: encodeAutosaveRecord(record), media: media),
        );
      }
    } on IOException {
      // Best-effort by contract: an unwritable disk means no autosave,
      // never a broken editor.
    }
  }

  @override
  Future<void> clear(String key) async {
    try {
      await File(pathFor(key)).delete();
    } on IOException {
      // Already gone (or unreachable) is as clear as it gets.
    }
  }
}
