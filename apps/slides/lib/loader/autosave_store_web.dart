// Browser-only glue: exercised by hand and compiled by the web_build CI
// job; tests inject fakes through the seam in `autosave_store.dart`.
// coverage:ignore-file
import 'dart:typed_data';

import 'package:slides/loader/autosave_record.dart';
import 'package:slides/loader/autosave_store.dart';
import 'package:web/web.dart' as web;

/// The web autosave store.
AutosaveStore platformAutosaveStore() => _WebAutosaveStore();

/// Web autosaves ride localStorage, one entry per deck key. localStorage
/// over IndexedDB deliberately: the store's contract is one small string
/// per deck, the recents list and the speaker handoff already live there,
/// and IndexedDB's request/event plumbing buys nothing testable for it.
/// The cost is the origin quota (about 5 MB), so writes are guarded: a
/// deck too large to fit is skipped — the previous record (if any) stays,
/// and editing is never interrupted. Session media bytes never fit that
/// quota at all, so a write drops them (the record alone survives) and the
/// recovery prompt owns the honesty: it names exactly which media needs
/// the original bundle before the autosave can open.
final class _WebAutosaveStore implements AutosaveStore {
  static const _prefix = 'fluvie_autosave:';

  /// Stays comfortably under the usual 5 MB origin quota, which the
  /// recents list and the speaker handoff share.
  static const int _maxCodeUnits = 4 * 1000 * 1000;

  @override
  Future<AutosaveSnapshot?> read(String key) async {
    final record = decodeAutosaveRecord(web.window.localStorage.getItem('$_prefix$key'));
    if (record == null) return null;
    return (record: record, media: const <String, Uint8List>{});
  }

  @override
  Future<void> write(
    String key,
    AutosaveRecord record, {
    Map<String, Uint8List> media = const {},
  }) async {
    final encoded = encodeAutosaveRecord(record);
    if (encoded.length > _maxCodeUnits) return;
    try {
      web.window.localStorage.setItem('$_prefix$key', encoded);
    } on Object {
      // QuotaExceededError and friends: best-effort by contract.
    }
  }

  @override
  Future<void> clear(String key) async => web.window.localStorage.removeItem('$_prefix$key');
}
