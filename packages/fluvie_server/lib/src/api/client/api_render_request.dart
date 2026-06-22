import 'package:meta/meta.dart';

/// A render request body, built on the client and sent to `POST /v1/renders`.
///
/// One factory per input mode (key/spec/prompt/edit); each accepts the same
/// export options plus visibility and ttl. [toJson] produces the exact wire
/// shape the server's `RenderRequest.fromJson` parses.
@immutable
final class ApiRenderRequest {
  const ApiRenderRequest._(this._json);

  /// Render a registered composition [key].
  factory ApiRenderRequest.key(
    String key, {
    String? format,
    String? aspect,
    String? quality,
    String? poster,
    String? visibility,
    String? ttl,
  }) => ApiRenderRequest._(
    _assemble({'key': key}, format, aspect, quality, poster, visibility, ttl),
  );

  /// Render a serialized `VideoSpec` [spec].
  factory ApiRenderRequest.spec(
    Map<String, Object?> spec, {
    String? format,
    String? aspect,
    String? quality,
    String? poster,
    String? visibility,
    String? ttl,
  }) => ApiRenderRequest._(
    _assemble({'spec': spec}, format, aspect, quality, poster, visibility, ttl),
  );

  /// Author a spec from a natural-language [prompt], then render it.
  factory ApiRenderRequest.prompt(
    String prompt, {
    String? provider,
    String? format,
    String? aspect,
    String? quality,
    String? poster,
    String? visibility,
    String? ttl,
  }) => ApiRenderRequest._(
    _assemble(
      {'prompt': prompt, 'provider': ?provider},
      format,
      aspect,
      quality,
      poster,
      visibility,
      ttl,
    ),
  );

  /// Refine [base] with a natural-language [change], then render it.
  factory ApiRenderRequest.edit({
    required Map<String, Object?> base,
    required String change,
    String? provider,
    String? format,
    String? aspect,
    String? quality,
    String? poster,
    String? visibility,
    String? ttl,
  }) => ApiRenderRequest._(
    _assemble(
      {
        'edit': {'base': base, 'change': change},
        'provider': ?provider,
      },
      format,
      aspect,
      quality,
      poster,
      visibility,
      ttl,
    ),
  );

  final Map<String, Object?> _json;

  /// The request as the JSON map the server expects.
  Map<String, Object?> toJson() => _json;

  static Map<String, Object?> _assemble(
    Map<String, Object?> input,
    String? format,
    String? aspect,
    String? quality,
    String? poster,
    String? visibility,
    String? ttl,
  ) {
    final options = {
      'format': ?format,
      'aspect': ?aspect,
      'quality': ?quality,
      'poster': ?poster,
    };
    return {
      ...input,
      if (options.isNotEmpty) 'options': options,
      'visibility': ?visibility,
      'ttl': ?ttl,
    };
  }
}
