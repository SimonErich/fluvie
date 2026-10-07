/// @docImport 'package:fluvie/src/composition/video.dart';
library;

// Launcher defines change the compile-time alias fallbacks; keep them explicit.
// ignore_for_file: avoid_redundant_argument_values

import 'dart:io';

import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/core/quality.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/rendering/render_options.dart';

part 'render_invocation_json.dart';

/// Settings passed by a render launcher, independent of `flutter_test`.
final class RenderInvocation {
  /// Creates an invocation. Null overrides retain the authored Video settings.
  const RenderInvocation({
    required this.outputDir,
    this.projectDir,
    this.compositionKey = 'render',
    this.frameCount,
    this.cacheEnabled = false,
    this.aspect,
    this.quality,
    this.export,
    this.posterTime,
    this.operation = 'render',
    this.frameIndex = 0,
    this.compositionFingerprint,
    this.reviewFrames = const [],
    this.reviewDeterminism = false,
    this.reviewOutputDir,
  });

  /// Parses a runtime worker request, rejecting unknown keys and invalid types.
  /// Paths belong to the caller; the worker transport must restrict output paths
  /// to its owned workspace before calling this factory.
  factory RenderInvocation.fromJson(Map<String, Object?> json) => _invocationFromJson(json);

  /// Reads the CLI adapter's compile-time settings.
  factory RenderInvocation.fromEnvironment() {
    const out = String.fromEnvironment(
      'FLUVIE_RENDER_OUT_DIR',
      defaultValue: String.fromEnvironment('FLUVIE_OUT_DIR'),
    );
    if (out.isEmpty) throw ArgumentError('FLUVIE_OUT_DIR must name the capture workspace.');
    const project = String.fromEnvironment('FLUVIE_PROJECT_DIR');
    const format = String.fromEnvironment(
      'FLUVIE_RENDER_FORMAT',
      defaultValue: String.fromEnvironment('FLUVIE_FORMAT'),
    );
    const frames = int.fromEnvironment(
      'FLUVIE_RENDER_FRAMES',
      defaultValue: int.fromEnvironment('FLUVIE_FRAMES'),
    );
    return RenderInvocation(
      outputDir: out,
      projectDir: project.isEmpty ? Directory.current.path : project,
      compositionKey: const String.fromEnvironment('FLUVIE_RENDER_KEY', defaultValue: 'render'),
      frameCount: frames > 0 ? frames : null,
      cacheEnabled: !const bool.fromEnvironment(
        'FLUVIE_RENDER_NO_CACHE',
        defaultValue: bool.fromEnvironment('FLUVIE_NO_CACHE', defaultValue: true),
      ),
      aspect: parseAspect(
        const String.fromEnvironment(
          'FLUVIE_RENDER_ASPECT',
          defaultValue: String.fromEnvironment('FLUVIE_ASPECT'),
        ),
      ),
      quality: parseQuality(
        const String.fromEnvironment(
          'FLUVIE_RENDER_QUALITY',
          defaultValue: String.fromEnvironment('FLUVIE_QUALITY'),
        ),
      ),
      export: format == 'mp4' ? const Export.mp4() : parseExportFormat(format),
      posterTime: parsePosterTime(
        const String.fromEnvironment(
          'FLUVIE_RENDER_POSTER',
          defaultValue: String.fromEnvironment('FLUVIE_POSTER'),
        ),
      ),
      operation: const String.fromEnvironment('FLUVIE_OPERATION', defaultValue: 'render'),
      frameIndex: const int.fromEnvironment('FLUVIE_FRAME'),
      compositionFingerprint: const String.fromEnvironment('FLUVIE_COMPOSITION_FINGERPRINT'),
      reviewFrames: const String.fromEnvironment(
        'FLUVIE_REVIEW_FRAMES',
      ).split(',').where((value) => value.isNotEmpty).map(int.parse).toList(),
      reviewDeterminism: const bool.fromEnvironment('FLUVIE_REVIEW_DETERMINISM'),
      reviewOutputDir: const String.fromEnvironment('FLUVIE_REVIEW_OUT_DIR'),
    );
  }

  /// Workspace for capture data or a custom renderer's encoded result.
  final String outputDir;

  /// Project root whose dropped assets augment the original Flutter bundle.
  final String? projectDir;

  /// Stable label used in progress and manifests.
  final String compositionKey;

  /// Explicit frame-count override, or the Video's total frames.
  final int? frameCount;

  /// Whether advisory captured-frame caching is enabled.
  final bool cacheEnabled;

  /// Optional aspect override.
  final Aspect? aspect;

  /// Optional encode-quality override.
  final Quality? quality;

  /// Optional export-format override.
  final Export? export;

  /// Optional poster override.
  final Time? posterTime;

  /// `render`, `inspect`, `frame`, `review`, or `audio`.
  final String operation;

  /// Absolute composition frame for the `frame` operation.
  final int frameIndex;

  /// Source/dependency fingerprint provided by a launcher for advisory caching.
  final String? compositionFingerprint;

  /// Requested absolute sample frames for review. Empty selects representative
  /// scene boundaries plus the first, middle, and final frames.
  final List<int> reviewFrames;

  /// Compare sample pixels after revisiting them in reverse seek order.
  final bool reviewDeterminism;

  /// Optional persistent directory for sample PNGs, outside the capture sandbox.
  final String? reviewOutputDir;
}
