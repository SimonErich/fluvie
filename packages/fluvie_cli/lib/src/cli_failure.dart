/// An operational CLI failure with a user-facing message.
///
/// The render command catches this at its boundary, prints [message] to
/// stderr and exits `1` — distinct from usage errors, which exit `64`.
final class CliFailure implements Exception {
  /// Creates a failure described by [message].
  const CliFailure(this.message, {this.code = 'command_failed', this.details = const {}});

  /// What went wrong, ready to print to stderr.
  final String message;

  /// Stable machine-readable cause, independent of the human message.
  final String code;

  /// Structured diagnostic context, such as an output verification receipt.
  final Map<String, Object?> details;

  @override
  String toString() => message;
}
