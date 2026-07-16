/// An invalid step setup, reported at compile time with the reason spelled
/// out — a duplicate explicit order, a trigger a revealed step cannot
/// resolve, or a deck whose timeline does not resolve at all.
final class StepCompileError implements Exception {
  /// Creates the error with its human-readable [message].
  const StepCompileError(this.message);

  /// What is wrong and where, phrased for the deck's author.
  final String message;

  @override
  String toString() => 'StepCompileError: $message';
}
