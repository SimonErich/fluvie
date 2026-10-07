part of 'render_invocation.dart';

RenderInvocation _invocationFromJson(Map<String, Object?> json) {
  const keys = {
    'outputDir',
    'projectDir',
    'compositionKey',
    'frameCount',
    'cacheEnabled',
    'aspect',
    'quality',
    'format',
    'poster',
    'operation',
    'frameIndex',
    'compositionFingerprint',
    'reviewFrames',
    'reviewDeterminism',
    'reviewOutputDir',
  };
  if (json.keys.any((key) => !keys.contains(key))) {
    throw ArgumentError('Unknown render invocation keys: ${json.keys.toSet().difference(keys)}');
  }
  String? string(String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String || value.isEmpty || value.contains('\u0000')) {
      throw ArgumentError.value(value, key, 'expected a nonempty string');
    }
    return value;
  }

  int? integer(String key, int minimum) {
    final value = json[key];
    if (value == null) return null;
    if (value is! int || value < minimum) {
      throw ArgumentError.value(value, key, 'expected an integer >= $minimum');
    }
    return value;
  }

  bool boolean(String key) {
    final value = json[key];
    if (value == null) return false;
    if (value is! bool) throw ArgumentError.value(value, key, 'expected a boolean');
    return value;
  }

  final output = string('outputDir');
  if (output == null) throw ArgumentError('outputDir is required.');
  final operation = string('operation') ?? 'render';
  if (!{'render', 'inspect', 'frame', 'audio', 'review'}.contains(operation)) {
    throw ArgumentError.value(operation, 'operation', 'unsupported operation');
  }
  final frames = json['reviewFrames'] ?? const <int>[];
  if (frames is! List || frames.length > 24 || frames.any((v) => v is! int || v < 0)) {
    throw ArgumentError.value(frames, 'reviewFrames', 'expected up to 24 non-negative integers');
  }
  final format = string('format');
  return RenderInvocation(
    outputDir: output,
    projectDir: string('projectDir'),
    compositionKey: string('compositionKey') ?? 'render',
    frameCount: integer('frameCount', 1),
    frameIndex: integer('frameIndex', 0) ?? 0,
    operation: operation,
    cacheEnabled: boolean('cacheEnabled'),
    aspect: parseAspect(string('aspect')),
    quality: parseQuality(string('quality')),
    export: format == 'mp4' ? const Export.mp4() : parseExportFormat(format),
    posterTime: parsePosterTime(string('poster')),
    compositionFingerprint: string('compositionFingerprint'),
    reviewFrames: List<int>.unmodifiable(frames.cast<int>()),
    reviewDeterminism: boolean('reviewDeterminism'),
    reviewOutputDir: string('reviewOutputDir'),
  );
}
