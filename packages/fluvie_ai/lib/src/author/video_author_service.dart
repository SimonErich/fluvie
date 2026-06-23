import 'dart:convert';

import 'package:fluvie/fluvie.dart';
import 'package:fluvie_ai/src/author/prompting.dart';
import 'package:fluvie_ai/src/client/ai_client.dart';

/// Turns a natural-language prompt into a validated [VideoSpec].
///
/// The model runs only here, at authoring time. Its output is a deterministic
/// spec; rendering that spec never calls a model.
// One member by design: the seam is the *type*, mocked behind its provider
// (new-service house pattern).
// ignore: one_member_abstracts
abstract interface class VideoAuthorService {
  /// Authors a spec from [prompt].
  ///
  /// Pass [base] to refine an existing spec, and [lastFrame] to ground the edit
  /// on a rendered preview. Throws an [AiClientException] if the model cannot
  /// produce a valid spec within the repair budget.
  Future<VideoSpec> author(String prompt, {VideoSpec? base, AiImage? lastFrame});
}

/// The default [VideoAuthorService]: schema-constrained generation with a
/// validate-then-repair loop over any [AiClient].
class LlmVideoAuthorService implements VideoAuthorService {
  /// Creates a service driving [client], validating against [schema] (defaults
  /// to Fluvie's [videoSpecSchema]) with up to [maxRepairs] correction rounds.
  LlmVideoAuthorService({
    required AiClient client,
    Map<String, Object?>? schema,
    int maxRepairs = 3,
  }) : _client = client, // ignore: prefer_initializing_formals — public arg, private field
       _schema = schema ?? videoSpecSchema,
       _maxRepairs = maxRepairs; // ignore: prefer_initializing_formals — public arg, private field

  final AiClient _client;
  final Map<String, Object?> _schema;
  final int _maxRepairs;

  @override
  Future<VideoSpec> author(String prompt, {VideoSpec? base, AiImage? lastFrame}) async {
    final messages = <AiMessage>[
      AiMessage.system(buildAuthorSystemPrompt(_schema)),
      AiMessage.user(_userPrompt(prompt, base), image: lastFrame),
    ];
    var attempt = 0;
    while (true) {
      final response = await _client.generate(
        AiRequest(messages: messages, jsonSchema: _schema),
      );
      try {
        return _parse(response.text);
      } on FluvieSpecError catch (error) {
        if (attempt >= _maxRepairs) {
          throw AiClientException(
            'Model output failed validation after ${attempt + 1} attempts: $error',
          );
        }
        attempt++;
        messages
          ..add(AiMessage.assistant(response.text))
          ..add(
            AiMessage.user(
              'That spec was invalid: $error\n'
              'Return a corrected JSON object only, with no other text.',
            ),
          );
      }
    }
  }

  String _userPrompt(String prompt, VideoSpec? base) {
    if (base == null) return prompt;
    final current = const JsonEncoder.withIndent('  ').convert(base.toJson());
    return 'Here is the current spec:\n$current\n\n'
        'Apply this change and return the full updated spec:\n$prompt';
  }

  VideoSpec _parse(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(_stripFences(text));
    } on FormatException catch (error) {
      throw FluvieSpecError('Model output was not valid JSON: ${error.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw FluvieSpecError('Model output was not a JSON object');
    }
    try {
      final spec = VideoSpec.fromJson(decoded);
      // Promote unknown properties (which `fromJson` would silently drop) to a
      // FluvieSpecError so the repair loop corrects an off-schema spec instead
      // of rendering one whose gradients, font sizes, or positions were dropped.
      assertNoUnknownSpecProps(decoded);
      return spec;
    } on FluvieSpecError {
      rethrow;
    } catch (error) {
      // A decoded-but-out-of-range value (e.g. {"repeat":{"times":0}}) trips a
      // core assertion rather than a FluvieSpecError. Convert it so the repair
      // loop corrects it instead of crashing the author with an AssertionError.
      throw FluvieSpecError('The spec contains a value Fluvie rejects: $error');
    }
  }

  /// Strips a leading/trailing markdown code fence a model may add despite the
  /// instruction not to.
  static String _stripFences(String text) {
    var trimmed = text.trim();
    if (trimmed.startsWith('```')) {
      final firstNewline = trimmed.indexOf('\n');
      if (firstNewline != -1) trimmed = trimmed.substring(firstNewline + 1);
      if (trimmed.endsWith('```')) trimmed = trimmed.substring(0, trimmed.length - 3);
    }
    return trimmed.trim();
  }
}
