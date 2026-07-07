import 'package:fluvie_ai/src/client/ai_image.dart';
import 'package:fluvie_ai/src/client/ai_role.dart';
import 'package:meta/meta.dart';

/// One message in an AI conversation.
@immutable
final class AiMessage {
  /// A system message that sets behavior.
  const AiMessage.system(this.text) : role = AiRole.system, image = null;

  /// A user message, optionally carrying an [image].
  const AiMessage.user(this.text, {this.image}) : role = AiRole.user;

  /// An assistant message echoing a previous model reply.
  const AiMessage.assistant(this.text) : role = AiRole.assistant, image = null;

  /// Who authored this message.
  final AiRole role;

  /// The message text.
  final String text;

  /// An optional inline image; `null` for text-only messages.
  final AiImage? image;
}
