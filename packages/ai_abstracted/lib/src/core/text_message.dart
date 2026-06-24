import 'package:meta/meta.dart';

/// Who authored a [TextMessage] in a conversation.
enum TextRole {
  /// A turn written by the human (or calling application).
  user,

  /// A turn returned previously by the assistant model.
  assistant,
}

/// One turn in a multi-turn text conversation.
///
/// Build prior turns with [TextMessage.user] and [TextMessage.assistant] and
/// pass them as the request history; the current user turn stays the request
/// prompt.
@immutable
final class TextMessage {
  /// Creates a [TextMessage] authored by the user.
  const TextMessage.user(this.text) : role = TextRole.user;

  /// Creates a [TextMessage] authored by the assistant.
  const TextMessage.assistant(this.text) : role = TextRole.assistant;

  /// Who authored this turn.
  final TextRole role;

  /// The turn's text content.
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TextMessage && other.role == role && other.text == text;

  @override
  int get hashCode => Object.hash(role, text);

  @override
  String toString() => 'TextMessage(${role.name}, $text)';
}
