/// An operational CLI failure with a user-facing message.
///
/// The render command catches this at its boundary, prints [message] to
/// stderr and exits `1` — distinct from usage errors, which exit `64`.
final class CliFailure implements Exception {
  /// Creates a failure described by [message].
  const CliFailure(this.message);

  /// What went wrong, ready to print to stderr.
  final String message;

  @override
  String toString() => message;
}
