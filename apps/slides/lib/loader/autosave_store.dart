import 'dart:typed_data';

import 'package:slides/loader/autosave_record.dart';
import 'package:slides/loader/autosave_store_io.dart'
    if (dart.library.js_interop) 'package:slides/loader/autosave_store_web.dart';

/// One autosave read back whole: the record plus the session media bytes
/// that survived beside it, keyed by bundle-relative value. Empty media where
/// the platform cannot hold it (the web's localStorage quota) or where the
/// deck referenced none.
typedef AutosaveSnapshot = ({AutosaveRecord record, Map<String, Uint8List> media});

/// Keeps the crash-recovery autosaves: sidecar files under the user's
/// config directory on desktop, localStorage on the web. One record per
/// deck key — the target path once a deck has one, its name before that.
/// A desktop write carrying session media becomes a bundle sidecar (the
/// `.fluvie` zip form), so a crashed session-media deck recovers with its
/// bytes; the web store keeps plain JSON and drops the media (its recovery
/// prompt says exactly what that means).
///
/// Autosave is best-effort by contract: implementations swallow their own
/// storage failures, so a full disk or a quota-bound browser degrades to
/// "no autosave" and never breaks editing.
abstract interface class AutosaveStore {
  /// The store for the running platform.
  factory AutosaveStore.platform() => platformAutosaveStore();

  /// The autosave under [key], or null when none exists or the stored
  /// record is unreadable.
  Future<AutosaveSnapshot?> read(String key);

  /// Writes [record] under [key], replacing any previous autosave. Pass the
  /// session [media] the document references so a crash cannot orphan it;
  /// a store that cannot hold bytes keeps the record alone.
  Future<void> write(String key, AutosaveRecord record, {Map<String, Uint8List> media});

  /// Deletes the autosave under [key]; a key that holds nothing is fine.
  Future<void> clear(String key);
}
