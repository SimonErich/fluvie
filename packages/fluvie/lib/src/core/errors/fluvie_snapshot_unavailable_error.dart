/// A missing snapshot *capability*: the host has no usable Chrome/Chromium to
/// rasterize a `Mermaid`/`WebView`/`Html` source, so no raster can be produced.
///
/// This is deliberately a sibling to `FluvieRenderException`, not a subtype:
/// a missing binary is an environment fault the operator
/// fixes by installing software, not a render fault inside a frame. Keeping it
/// separate means a render-level `catch` never silently swallows "install
/// Chrome", and a blank frame is never produced in its place. The message names
/// the missing capability; the optional [installHint] names the fix so the
/// operator can act on it.
///
/// This is a pure exception in `core` (not `diagnostics`): every layer above
/// may throw and catch it without violating the layering law.
final class FluvieSnapshotUnavailableError implements Exception {
  /// Creates the error described by [message], optionally carrying an
  /// [installHint] that names how to provide the missing capability.
  FluvieSnapshotUnavailableError(this.message, {this.installHint});

  /// What capability is missing, in one actionable sentence.
  final String message;

  /// How to provide the missing capability (for example, an install command),
  /// or `null` when no single fix applies.
  final String? installHint;

  @override
  String toString() {
    final buffer = StringBuffer('FluvieSnapshotUnavailableError: $message');
    final hint = installHint;
    if (hint != null) buffer.write('\nTo fix: $hint');
    return buffer.toString();
  }
}
