import 'dart:async' show Timer, unawaited;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:slides/loader/autosave_record.dart';
import 'package:slides/loader/autosave_store.dart';

/// Debounced crash protection for the editor: every document change arms a
/// short timer, and when the edits quiet down the working document lands in
/// the [AutosaveStore] — stamped with its digest, the time, and the record
/// format version. A document back at its saved state clears the record
/// instead, so an orderly session leaves nothing behind to "recover".
///
/// Autosave is strictly best-effort: every store failure is swallowed. The
/// worst a broken disk or a full quota can do is leave no (or an older)
/// autosave — it never interrupts editing.
final class AutosaveController {
  /// Wires the controller over [store], starting at [key] (the deck's
  /// target path once it has one, its name before that). The document
  /// callbacks are pulled lazily at fire time, so arming the timer on
  /// every keystroke costs nothing.
  AutosaveController({
    required this.store,
    required this._key,
    required this.documentJson,
    required this.documentDigest,
    required this.isDirty,
    this.media = _noMedia,
    this.debounce = const Duration(seconds: 2),
    DateTime Function()? now,
    this.onChanged,
  }) : now = now ?? DateTime.now;

  static Map<String, Uint8List> _noMedia() => const {};

  /// Where autosaves live.
  final AutosaveStore store;

  /// The document's JSON text, exactly what a save would write.
  final String Function() documentJson;

  /// The editor-side digest of the current document.
  final String Function() documentDigest;

  /// Whether unsaved changes exist right now.
  final bool Function() isDirty;

  /// The session media bytes the document references right now, pulled at
  /// fire time like the other callbacks. What the store keeps beside the
  /// record so a crash cannot orphan a session-media deck.
  final Map<String, Uint8List> Function() media;

  /// How long the edits must quiet down before a write.
  final Duration debounce;

  /// The clock (injectable so tests pin timestamps).
  final DateTime Function() now;

  /// Hears about every store round-trip and retarget, so the quiet
  /// indicator can refresh.
  final VoidCallback? onChanged;

  String _key;
  Timer? _timer;
  DateTime? _lastAt;
  String? _lastDigest;

  /// The key autosaves are stored under right now.
  String get key => _key;

  /// When the last successful autosave was written, or null when the
  /// stored record no longer exists (cleared, retargeted, or never written).
  DateTime? get lastAutosaveAt => _lastAt;

  /// The document digest the last successful autosave covers, or null.
  String? get lastAutosaveDigest => _lastDigest;

  /// (Re)arms the debounce; call on every document change.
  void changed() {
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      unawaited(_fire());
    });
  }

  /// Runs a pending autosave right now (Present and the clean close call
  /// this); quiet when nothing is pending.
  Future<void> flush() async {
    final timer = _timer;
    if (timer == null) return;
    timer.cancel();
    _timer = null;
    await _fire();
  }

  /// A completed save: the covered autosave clears, future autosaves land
  /// under [newKey] (the fresh target path, or the name where paths mean
  /// nothing), and edits made while the save dialog was up re-arm.
  Future<void> saved(String newKey) async {
    await _drop();
    _key = newKey;
    onChanged?.call();
    if (isDirty()) changed();
  }

  /// An explicit discard: the user chose to drop the changes, so the
  /// autosave goes with them.
  Future<void> discard() async {
    await _drop();
    onChanged?.call();
  }

  /// Cancels any pending write. Never touches the store: a disposed editor
  /// is not a saved one, and the last autosave must survive a crash.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _drop() async {
    _timer?.cancel();
    _timer = null;
    try {
      await store.clear(_key);
    } on Object {
      // Best-effort by contract.
    }
    _lastAt = null;
    _lastDigest = null;
  }

  Future<void> _fire() async {
    try {
      if (isDirty()) {
        final at = now();
        final digest = documentDigest();
        await store.write(
          _key,
          AutosaveRecord(json: documentJson(), savedAt: at, digest: digest),
          media: media(),
        );
        _lastAt = at;
        _lastDigest = digest;
      } else {
        await store.clear(_key);
        _lastAt = null;
        _lastDigest = null;
      }
      onChanged?.call();
    } on Object {
      // A failed write leaves the previous record (or none); editing is
      // never interrupted.
    }
  }
}
