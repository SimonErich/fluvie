/// A render-pipeline failure: a capture that could not produce a frame, a
/// boundary that is missing or the wrong render object, a dimension mismatch,
/// or any other fault between the frame loop and the encoder's input.
///
/// This is the base type for everything that goes wrong *while rendering*
/// (as opposed to [Exception]s from timing resolution, which fail before any
/// frame is produced). Encoding-specific failures carry process detail on the
/// `FluvieEncodeException` subtype.
///
/// This is a pure exception in `core` (not `diagnostics`): every layer above
/// may throw and catch it without violating the layering law.
class FluvieRenderException implements Exception {
  /// Creates a render exception described by [message].
  FluvieRenderException(this.message);

  /// What went wrong, in one actionable sentence.
  final String message;

  @override
  String toString() => 'FluvieRenderException: $message';
}
