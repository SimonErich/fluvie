import 'dart:convert';

import 'package:fluvie/src/core/hash/fnv1a.dart';
import 'package:fluvie/src/core/media/generative_kind.dart';
import 'package:meta/meta.dart';

/// One declared piece of AI-generated media, identified before it is produced.
///
/// A `GenerativeSource` is the key the prerender pass gathers from the widget
/// tree (through `GenerativeCarrier`): a generation backend produces it once,
/// caches it by [cacheKey], and folds the result back in as a plain
/// `MediaSource`/`AudioSource`. It carries only Dart-core types, so it satisfies
/// the layering law and lives in `core` (no IO, no provider knowledge).
///
/// [cacheKey] is the FNV-1a-64 hash of a canonical string over the provider,
/// model, seed, sorted [params], and prompt. The seed drives reuse exactly: with
/// no [seed], one identical prompt yields a single stable key (reused forever);
/// with a [seed], each distinct seed yields a distinct key, still deterministic
/// per `(prompt, seed)`. [params] are order-independent and must be JSON values.
///
/// `GenerativeCarrier`, `MediaSource` and a generation backend are named in
/// prose, not as doc links, because they live in layers above `core`.
@immutable
final class GenerativeSource {
  const GenerativeSource._({
    required this.kind,
    required this.providerId,
    required this.prompt,
    this.model,
    this.seed,
    this.params = const {},
  });

  /// A generated video by [providerId] from [prompt] (for example Veo). [params]
  /// carry provider options such as `seconds` or `withAudio`.
  const GenerativeSource.video({
    required String providerId,
    required String prompt,
    String? model,
    String? seed,
    Map<String, Object?> params = const {},
  }) : this._(
         kind: GenerativeKind.video,
         providerId: providerId,
         prompt: prompt,
         model: model,
         seed: seed,
         params: params,
       );

  /// A generated still image by [providerId] from [prompt] (for example Flux).
  const GenerativeSource.image({
    required String providerId,
    required String prompt,
    String? model,
    String? seed,
    Map<String, Object?> params = const {},
  }) : this._(
         kind: GenerativeKind.image,
         providerId: providerId,
         prompt: prompt,
         model: model,
         seed: seed,
         params: params,
       );

  /// A generated music track by [providerId] from [prompt] (for example Suno).
  const GenerativeSource.music({
    required String providerId,
    required String prompt,
    String? model,
    String? seed,
    Map<String, Object?> params = const {},
  }) : this._(
         kind: GenerativeKind.music,
         providerId: providerId,
         prompt: prompt,
         model: model,
         seed: seed,
         params: params,
       );

  /// Generated speech by [providerId] from [prompt] — the text to speak (for
  /// example ElevenLabs).
  const GenerativeSource.speech({
    required String providerId,
    required String prompt,
    String? model,
    String? seed,
    Map<String, Object?> params = const {},
  }) : this._(
         kind: GenerativeKind.speech,
         providerId: providerId,
         prompt: prompt,
         model: model,
         seed: seed,
         params: params,
       );

  /// A generated sound effect by [providerId] from [prompt] (for example
  /// ElevenLabs sound generation).
  const GenerativeSource.soundEffect({
    required String providerId,
    required String prompt,
    String? model,
    String? seed,
    Map<String, Object?> params = const {},
  }) : this._(
         kind: GenerativeKind.soundEffect,
         providerId: providerId,
         prompt: prompt,
         model: model,
         seed: seed,
         params: params,
       );

  /// What this source produces (drives whether it resolves to media or audio).
  final GenerativeKind kind;

  /// The backend that produces this source (for example `veo`, `flux`, `suno`).
  final String providerId;

  /// The natural-language prompt (for speech, the text to speak).
  final String prompt;

  /// The provider model id, or `null` for the provider default.
  final String? model;

  /// The reuse seed, or `null` for a single shared result per prompt.
  final String? seed;

  /// Provider options that change the output (JSON values; order-independent).
  final Map<String, Object?> params;

  /// Whether this source resolves to an `AudioSource`.
  bool get isAudio => kind.isAudio;

  /// Whether this source resolves to a visual `MediaSource`.
  bool get isVisual => kind.isVisual;

  String get _paramsCanonical {
    final keys = params.keys.toList()..sort();
    return jsonEncode({for (final key in keys) key: params[key]});
  }

  String get _canonical =>
      '${kind.name}|$providerId|${model ?? ''}|${seed ?? ''}|$_paramsCanonical|$prompt';

  /// The path-safe content-hash key (FNV-1a-64) for the generative cache.
  String get cacheKey => fnv1a64Hex(utf8.encode(_canonical));

  @override
  bool operator ==(Object other) => other is GenerativeSource && other._canonical == _canonical;

  @override
  int get hashCode => _canonical.hashCode;

  @override
  String toString() =>
      'GenerativeSource.${kind.name}($providerId, ${prompt.length} chars, seed: $seed)';
}
