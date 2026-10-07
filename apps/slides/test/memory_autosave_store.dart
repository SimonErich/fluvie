import 'dart:typed_data';

import 'package:slides/loader/autosave_record.dart';
import 'package:slides/loader/autosave_store.dart';

/// An in-memory autosave store (what localStorage or the sidecar files
/// hold) that also counts its calls. Every test that mounts the editor
/// injects one so no test ever touches the real config directory.
final class MemoryAutosaveStore implements AutosaveStore {
  /// The stored records by deck key.
  final Map<String, AutosaveRecord> records = {};

  /// The session media bytes stored beside each record, by deck key.
  final Map<String, Map<String, Uint8List>> media = {};

  /// How many writes happened.
  int writes = 0;

  /// How many clears happened.
  int clears = 0;

  @override
  Future<AutosaveSnapshot?> read(String key) async {
    final record = records[key];
    if (record == null) return null;
    return (record: record, media: media[key] ?? const {});
  }

  @override
  Future<void> write(
    String key,
    AutosaveRecord record, {
    Map<String, Uint8List> media = const {},
  }) async {
    writes++;
    records[key] = record;
    if (media.isEmpty) {
      this.media.remove(key);
    } else {
      this.media[key] = Map.of(media);
    }
  }

  @override
  Future<void> clear(String key) async {
    clears++;
    records.remove(key);
    media.remove(key);
  }
}
