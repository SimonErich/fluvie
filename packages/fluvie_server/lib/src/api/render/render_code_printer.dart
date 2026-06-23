// printVideoSpecJson is @experimental in fluvie_cli; the server depends on it
// deliberately as the canonical spec→Dart printer for AI renders.
// ignore_for_file: experimental_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/fluvie_cli.dart' show printVideoSpecJson;

/// Prints a decoded `VideoSpec` [spec] as a Flutter-style Dart `Video build()`
/// snippet — the editable code the Playground shows.
///
/// A pure transformation: it neither calls an LLM nor renders. Throws a
/// [FormatException] when the spec is malformed, so a caller can report the
/// problem to the user.
String printSpecMap(Map<String, Object?> spec) => printVideoSpecJson(spec);

/// Reads the authored `VideoSpec` JSON at [specPath] and returns it as a decoded
/// `Map<String, Object?>`, or `null` when the file is missing or not a JSON
/// object.
///
/// This is the spec the Playground hands back to the AI Assistant as the `base`
/// of a surgical edit. A read or parse failure never throws: the render still
/// returns and the spec is simply absent.
Map<String, Object?>? readSpecFileOrNull(String specPath) {
  final file = File(specPath);
  if (!file.existsSync()) return null;
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    return decoded is Map<String, Object?> ? decoded : null;
  } on Object catch (error) {
    stderr.writeln('fluvie_server: could not read authored spec at $specPath: $error');
    return null;
  }
}

/// Watches the authored-spec file an AI render writes during capture and prints
/// it to Dart as soon as it appears, so a polling client sees the code (and the
/// spec) before the video finishes.
///
/// The watcher polls until the spec is printable, fires [onAuthored] exactly
/// once (whether the poll or a final [flush] catches it) with both the printed
/// [code] and the decoded [spec], and exposes both. A malformed spec leaves
/// [code] and [spec] `null` and never fires the callback.
final class SpecCodeWatcher {
  /// Creates a watcher for the spec at [specPath]. [onAuthored] is optional;
  /// [code] and [spec] are populated regardless so the caller can read them
  /// after [flush].
  SpecCodeWatcher({
    required this.specPath,
    required Duration interval,
    this.onAuthored,
  }) {
    _timer = Timer.periodic(interval, (_) => _tryEmit());
  }

  /// The spec file path to watch.
  final String specPath;

  /// Fired once with the printed snippet and the decoded spec as soon as the
  /// spec is printable.
  final void Function(String code, Map<String, Object?> spec)? onAuthored;

  late final Timer _timer;
  bool _emitted = false;

  /// The printed Dart snippet once available, else `null`.
  String? code;

  /// The decoded authored spec once available, else `null`. Set at the same
  /// moment as [code] so the two never drift.
  Map<String, Object?>? spec;

  /// Stops watching and prints the spec one last time if the poll never caught
  /// it (a fast render where the spec landed only at the end).
  void flush() {
    _timer.cancel();
    _tryEmit();
  }

  void _tryEmit() {
    if (_emitted) return;
    final decoded = readSpecFileOrNull(specPath);
    if (decoded == null) return;
    final String printed;
    try {
      printed = printSpecMap(decoded);
    } on Object catch (error) {
      // A spec the printer rejects must never fail the render: leave code/spec
      // null and stay silent for the caller (logged once for the operator).
      stderr.writeln('fluvie_server: could not print authored spec at $specPath: $error');
      return;
    }
    _emitted = true;
    code = printed;
    spec = decoded;
    onAuthored?.call(printed, decoded);
  }
}
