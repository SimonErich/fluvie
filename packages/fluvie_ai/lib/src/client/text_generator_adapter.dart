import 'dart:convert';

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:fluvie_ai/src/client/ai_client.dart';

/// Runs [request] through an `ai_abstracted` [TextGenerator] and returns the
/// model's reply as an [AiResponse].
///
/// Maps the authoring [AiRequest] onto a [TextRequest]: system messages join
/// with a blank line into [TextRequest.system] (null when there are none), the
/// non-system messages become [TextRequest.history] for all but the last (each
/// mapped to a [TextMessage]), and the last non-system message becomes the
/// [TextRequest.prompt] plus its optional [TextRequest.image]. The token ceiling,
/// temperature, JSON schema, and the optional [model] override carry through.
///
/// Wraps any [AiException] the generator raises as an [AiClientException] with
/// the same message, so consumers keep handling the one authoring error type.
Future<AiResponse> generateViaTextGenerator(
  TextGenerator generator,
  AiRequest request, {
  String? model,
}) async {
  final systemText = request.messages
      .where((message) => message.role == AiRole.system)
      .map((message) => message.text)
      .join('\n\n');
  final turns = request.messages.where((message) => message.role != AiRole.system).toList();
  final last = turns.isEmpty ? null : turns.last;
  final priorTurns = turns.isEmpty ? const <AiMessage>[] : turns.sublist(0, turns.length - 1);
  final textRequest = TextRequest(
    prompt: last?.text ?? '',
    model: model,
    system: systemText.isEmpty ? null : systemText,
    history: [
      for (final turn in priorTurns)
        turn.role == AiRole.assistant
            ? TextMessage.assistant(turn.text)
            : TextMessage.user(turn.text),
    ],
    image: _imageOf(last),
    maxTokens: request.maxTokens,
    temperature: request.temperature,
    jsonSchema: request.jsonSchema,
  );
  try {
    final result = await generator.generateText(textRequest);
    return AiResponse(utf8.decode(result.bytes));
  } on AiException catch (error) {
    throw AiClientException(error.message);
  }
}

/// The last turn's image mapped to a [TextImage], or null when absent.
TextImage? _imageOf(AiMessage? message) {
  final image = message?.image;
  if (image == null) {
    return null;
  }
  return TextImage(bytes: image.bytes, mimeType: image.mediaType);
}
