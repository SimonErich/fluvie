import 'dart:convert';

import 'package:fluvie_ai/src/client/ai_client.dart';
import 'package:fluvie_validate/source_edits.dart';

/// Authors exact Dart patches with bounded repairs against immutable source.
/// The shared validator rejects ambiguous and overlapping ranges; a host must
/// still analyze and mount the candidate before publishing it.
final class DartEditService {
  /// Uses [client] for at most [maxAttempts] replies.
  DartEditService({required this.client, this.maxAttempts = 3}) {
    if (maxAttempts < 1 || maxAttempts > 5) throw ArgumentError('Use 1..5 edit attempts.');
  }

  /// Caller-owned model transport.
  final AiClient client;

  /// Total request budget, including the first attempt.
  final int maxAttempts;

  /// Returns validated patch JSON without changing [source]. Unrelated bytes
  /// remain untouched when the caller applies this reply to the same source.
  Future<String> edit(
    String prompt, {
    required String source,
    String context = '',
    List<AiImage> evidenceImages = const [],
  }) async {
    if (source.isEmpty || utf8.encode(source).length > 256 * 1024) {
      throw ArgumentError('Dart edits accept nonempty source up to 256 KiB.');
    }
    final messages = <AiMessage>[
      const AiMessage.system(
        'Edit the supplied Flutter/Fluvie Dart composition. Preserve handwritten '
        'widgets, imports, comments and unrelated formatting. Reply with ONLY {"edits":[{"before":"...","after":"..."}]}. '
        'Use 1..32 replacements. Each nonempty before must match exactly once in the ORIGINAL source. '
        'Include surrounding Dart fields when a token repeats: 3.seconds also occurs inside 0.3.seconds. '
        'Use supplied installed API examples; never invent named parameters. '
        'JSON line-break escapes must decode to real newlines, not literal backslash-n tokens between Dart declarations. '
        'Ranges must not overlap. Make the smallest changes that satisfy the request. '
        'Do not return a whole file, explanation or VideoSpec. The result is compiled before publication.',
      ),
      AiMessage.user('$prompt\n\n$context\n\nORIGINAL DART SOURCE:\n$source'),
      for (final image in evidenceImages)
        AiMessage.user(image.description ?? 'Selected image evidence', image: image),
    ];
    String? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final reply = await client.generate(
        AiRequest(messages: List.unmodifiable(messages), jsonSchema: _editSchema, temperature: 0.2),
      );
      try {
        applyDartSourceEdits(source, reply.text);
        return reply.text;
      } on SourceEditException catch (error) {
        lastError = error.message;
        messages.addAll([
          AiMessage.assistant(reply.text),
          AiMessage.user(
            'Repair this reply: ${error.message} Use the unchanged ORIGINAL source and return only the edits object.',
          ),
        ]);
      }
    }
    throw AiClientException('Dart editing failed after $maxAttempts replies: $lastError');
  }
}

const _editSchema = <String, Object?>{
  'type': 'object',
  'required': ['edits'],
  'additionalProperties': false,
  'properties': {
    'edits': {
      'type': 'array',
      'minItems': 1,
      'maxItems': 32,
      'items': {
        'type': 'object',
        'required': ['before', 'after'],
        'additionalProperties': false,
        'properties': {
          'before': {'type': 'string'},
          'after': {'type': 'string'},
        },
      },
    },
  },
};
