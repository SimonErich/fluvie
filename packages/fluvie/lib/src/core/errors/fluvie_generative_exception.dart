/// A failure producing AI-generated media before the frame loop: a provider
/// error, a missing generation backend, an offline cache miss, or a budget
/// overrun.
///
/// Thrown by the prerender pass (before any frame is produced), so a caught
/// generation failure is cleanly distinct from a `FluvieRenderException` raised
/// while capturing. It is a pure exception in `core` (not `diagnostics`): every
/// layer above may throw and catch it without violating the layering law.
///
/// `FluvieRenderException` is named in prose, not as a doc link, to avoid a
/// cross-reference that would not survive the layering.
class FluvieGenerativeException implements Exception {
  /// Creates a generative exception described by [message].
  FluvieGenerativeException(this.message);

  /// What went wrong, in one actionable sentence (names the provider and prompt
  /// where the throwing code knows them).
  final String message;

  @override
  String toString() => 'FluvieGenerativeException: $message';
}
