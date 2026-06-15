/// A serialization failure: a malformed `VideoSpec` document, an unknown
/// element/preset/enum name, or a Fluvie value that has no JSON form.
///
/// Fluvie throws this while reading or writing a spec — never mid-render — so a
/// bad document fails fast with an actionable message naming where in the
/// document the problem is. The [path] is the chain of JSON keys/indices from
/// the document root to the offending node (for example
/// `scenes.0.children.1.animate.0`).
///
/// This is a pure exception in `core` (not `diagnostics`): every layer above —
/// including the serialization layer and the AI authoring package — may throw
/// and catch it without violating the layering law.
class FluvieSpecError implements Exception {
  /// Creates a spec error described by [message], optionally locating it at the
  /// document [path].
  FluvieSpecError(this.message, {this.path = const []});

  /// What went wrong, in one actionable sentence.
  final String message;

  /// The chain of JSON keys/indices from the document root to the offending
  /// node, in order. Empty when no location applies.
  final List<String> path;

  @override
  String toString() => path.isEmpty
      ? 'FluvieSpecError: $message'
      : 'FluvieSpecError: $message (at ${path.join('.')})';
}
