import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/media/media_store_entry.dart';
import 'package:fluvie_editor/src/tools/media_importer.dart';

/// The store entry a fresh import of [pick] should record in [document], or
/// null when there is nothing to record: a reuse pick (no name) or a source
/// the store already holds.
MediaStoreEntry? storeEntryFor(EditorDocument document, MediaPick pick) {
  final name = pick.name;
  if (name == null) return null;
  final alreadyHeld = document.mediaEntries.any(
    (entry) =>
        entry.source['kind'] == pick.source['kind'] &&
        entry.source['value'] == pick.source['value'],
  );
  if (alreadyHeld) return null;
  return MediaStoreEntry(
    id: document.nextMediaId(),
    name: name,
    kind: pick.isAudio
        ? MediaStoreKind.audio
        : pick.isVideo
        ? MediaStoreKind.video
        : MediaStoreKind.image,
    source: Map<String, Object?>.of(pick.source),
    sizeBytes: pick.sizeBytes,
    duration: pick.duration,
    width: pick.width,
    height: pick.height,
    fps: pick.fps,
    channels: pick.channels,
  );
}

/// Every bundle-relative media value the document's *content* references —
/// element sources and posters (groups included) and audio tracks at both
/// levels. The editor block does not count: an unreferenced store entry does
/// not force a bundle save. This is what a save must pack (or warn about,
/// when it saves plain JSON).
Set<String> referencedBundleValues(EditorDocument document) {
  final json = document.toJson()..remove('editor');
  final values = <String>{};
  _collectBundleValues(json, values);
  return values;
}

/// Bundle assets needed to reopen the complete editor project, including media
/// imported into the bin that has not yet been placed on the timeline.
Set<String> documentBundleValues(EditorDocument document) {
  final values = referencedBundleValues(document);
  for (final entry in document.mediaEntries) {
    _collectBundleValues(entry.source, values);
  }
  return values;
}

void _collectBundleValues(Object? node, Set<String> out) {
  if (node is Map<String, Object?>) {
    final value = node['value'];
    if (node['kind'] == 'bundle' && value is String) out.add(value);
    for (final child in node.values) {
      _collectBundleValues(child, out);
    }
  } else if (node is List) {
    for (final child in node) {
      _collectBundleValues(child, out);
    }
  }
}
