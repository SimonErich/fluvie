// fluvie:large-file-ok: one sealed RenderRequest one-of; the base, its five
// variants, and the shared body parser must live in the same library for the
// exhaustive switch, so this stays a single cohesive surface.
import 'package:fluvie_cli/fluvie_cli.dart' show aspectNames, formatNames, qualityNames;
import 'package:fluvie_server/src/api/jobs/render_job.dart';

/// The validated export options on a render request (each `null` = the default).
typedef ExportOptions = ({String? format, String? aspect, String? quality, String? poster});

const ExportOptions _noOptions = (format: null, aspect: null, quality: null, poster: null);

/// A render request parsed from an HTTP body: exactly one of a registry key, a
/// spec, an AI prompt, an AI edit, or a Dart code snippet, plus export
/// [options].
sealed class RenderRequest {
  const RenderRequest(this.options);

  /// The export options (format/aspect/quality/poster).
  final ExportOptions options;

  /// The job kind this request maps to.
  RenderJobKind get kind;

  /// Parses a request from a decoded JSON [json] object, validating that exactly
  /// one input is present and that the export options name valid values. Throws
  /// a [RenderRequestException] (HTTP 400) on any problem.
  static RenderRequest fromJson(Map<String, Object?> json) {
    final options = _options(json['options']);
    final inputs = ['key', 'spec', 'prompt', 'edit', 'code'].where(json.containsKey).toList();
    if (inputs.length != 1) {
      throw const RenderRequestException('Provide exactly one of key, spec, prompt, edit, code.');
    }
    final provider = _optionalString(json, 'provider');
    return switch (inputs.single) {
      'key' => KeyRenderRequest(_key(json), options),
      'spec' => SpecRenderRequest(_spec(json['spec'], 'spec'), options),
      'prompt' => PromptRenderRequest(_nonEmpty(json, 'prompt'), provider, options),
      'code' => CodeRenderRequest(_nonEmpty(json, 'code'), options),
      _ => _edit(json, provider, options),
    };
  }

  static EditRenderRequest _edit(
    Map<String, Object?> json,
    String? provider,
    ExportOptions options,
  ) {
    final edit = json['edit'];
    if (edit is! Map<String, Object?>) {
      throw const RenderRequestException('edit must be an object with base and change.');
    }
    final change = edit['change'];
    if (change is! String || change.trim().isEmpty) {
      throw const RenderRequestException('edit.change must be a non-empty string.');
    }
    return EditRenderRequest(_spec(edit['base'], 'edit.base'), change.trim(), provider, options);
  }

  static Map<String, Object?> _spec(Object? value, String field) {
    if (value is! Map<String, Object?>) {
      throw RenderRequestException('$field must be a VideoSpec object.');
    }
    final scenes = value['scenes'];
    if (scenes is! List || scenes.isEmpty) {
      throw RenderRequestException('$field must have a non-empty "scenes" list.');
    }
    return value;
  }

  static String _key(Map<String, Object?> json) {
    final key = _nonEmpty(json, 'key');
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(key)) {
      throw const RenderRequestException('key must be lowercase snake_case.');
    }
    return key;
  }

  static String _nonEmpty(Map<String, Object?> json, String field) {
    final value = json[field];
    if (value is! String || value.trim().isEmpty) {
      throw RenderRequestException('$field must be a non-empty string.');
    }
    return value.trim();
  }

  static String? _optionalString(Map<String, Object?> json, String field) {
    final value = json[field];
    if (value == null) return null;
    if (value is! String) throw RenderRequestException('$field must be a string.');
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static ExportOptions _options(Object? raw) {
    if (raw == null) return _noOptions;
    if (raw is! Map<String, Object?>) {
      throw const RenderRequestException('options must be an object.');
    }
    final format = _enum(raw, 'format', formatNames);
    if (format == 'imageSequence') {
      throw const RenderRequestException(
        'options.format imageSequence is not supported over HTTP (it produces many files).',
      );
    }
    return (
      format: format,
      aspect: _enum(raw, 'aspect', aspectNames),
      quality: _enum(raw, 'quality', qualityNames),
      poster: _poster(raw),
    );
  }

  static String? _enum(Map<String, Object?> raw, String field, List<String> allowed) {
    final value = raw[field];
    if (value == null) return null;
    if (value is! String || !allowed.contains(value)) {
      throw RenderRequestException('options.$field must be one of ${allowed.join(', ')}.');
    }
    return value;
  }

  static String? _poster(Map<String, Object?> raw) {
    final value = raw['poster'];
    if (value == null) return null;
    if (value is! String || value.isEmpty) {
      throw const RenderRequestException('options.poster must be a non-empty Time string.');
    }
    return value;
  }
}

/// Render a registered composition [key].
final class KeyRenderRequest extends RenderRequest {
  /// Creates a key request.
  const KeyRenderRequest(this.key, super.options);

  /// The registry key.
  final String key;

  @override
  RenderJobKind get kind => RenderJobKind.key;
}

/// Render a serialized `VideoSpec` document.
final class SpecRenderRequest extends RenderRequest {
  /// Creates a spec request.
  const SpecRenderRequest(this.spec, super.options);

  /// The decoded spec JSON.
  final Map<String, Object?> spec;

  @override
  RenderJobKind get kind => RenderJobKind.spec;
}

/// Author a spec from a natural-language [prompt], then render it.
final class PromptRenderRequest extends RenderRequest {
  /// Creates a prompt request.
  const PromptRenderRequest(this.prompt, this.provider, super.options);

  /// The natural-language prompt.
  final String prompt;

  /// An optional LLM provider override.
  final String? provider;

  @override
  RenderJobKind get kind => RenderJobKind.prompt;
}

/// Render a user-submitted Dart `Video build()` snippet (the Playground).
///
/// The snippet is statically validated (analysis + import allowlist) before it
/// is enqueued, then executed inside an isolated `flutter test` capture.
final class CodeRenderRequest extends RenderRequest {
  /// Creates a code request.
  const CodeRenderRequest(this.code, super.options);

  /// The Dart source defining a top-level `Video build()`.
  final String code;

  @override
  RenderJobKind get kind => RenderJobKind.code;
}

/// Refine [baseSpec] with a natural-language [change], then render it.
final class EditRenderRequest extends RenderRequest {
  /// Creates an edit request.
  const EditRenderRequest(this.baseSpec, this.change, this.provider, super.options);

  /// The base spec to refine.
  final Map<String, Object?> baseSpec;

  /// The natural-language change.
  final String change;

  /// An optional LLM provider override.
  final String? provider;

  @override
  RenderJobKind get kind => RenderJobKind.edit;
}

/// Thrown for an invalid render request body (mapped to HTTP 400).
final class RenderRequestException implements Exception {
  /// Creates the exception with a client-safe [message].
  const RenderRequestException(this.message);

  /// What was wrong with the request.
  final String message;

  @override
  String toString() => 'RenderRequestException: $message';
}
