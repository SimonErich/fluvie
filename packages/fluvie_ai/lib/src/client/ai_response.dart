import 'package:meta/meta.dart';

/// A reply from an `AiClient`.
@immutable
final class AiResponse {
  /// Creates a response carrying the model's [text] (JSON when a schema was set).
  const AiResponse(this.text);

  /// The model's reply text.
  final String text;
}
