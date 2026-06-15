import 'package:flutter/foundation.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';

/// The capture sandbox's completion signal and encode plan, written **last**
/// (after the frames file is complete) as `manifest.json`.
///
/// This is the single source of ffmpeg-arg truth: the capture
/// side embeds the complete encode argument array, every path in it
/// sandbox-relative, and the CLI spawns ffmpeg with exactly [ffmpegArgs] —
/// it never composes arguments itself. [RenderManifest.fromJson] rejects an
/// unknown [schemaVersion] so a capture/CLI version skew fails loudly instead
/// of encoding garbage.
@immutable
final class RenderManifest {
  /// Creates a manifest describing one completed capture.
  ///
  /// [posterArgs]/[posterFileName] are present together only when the
  /// composition declares a `Video.poster`: the SECOND ffmpeg invocation that
  /// extracts the poster still.
  RenderManifest({
    required this.width,
    required this.height,
    required this.fps,
    required this.frameCount,
    required this.framesFileName,
    required this.outputFileName,
    required this.renderDigest,
    required List<String> ffmpegArgs,
    List<String>? posterArgs,
    this.posterFileName,
  }) : ffmpegArgs = List.unmodifiable(ffmpegArgs),
       posterArgs = posterArgs == null ? null : List<String>.unmodifiable(posterArgs);

  /// Reads a manifest from its [toJson] form.
  ///
  /// Throws a [FluvieRenderException] when `json['schemaVersion']` is not
  /// [schemaVersion].
  factory RenderManifest.fromJson(Map<String, Object?> json) {
    final version = json['schemaVersion'];
    if (version != schemaVersion) {
      throw FluvieRenderException(
        'Unsupported render-manifest schemaVersion "$version" (this fluvie '
        'reads version $schemaVersion). The capture and encode sides must run '
        'matching fluvie versions.',
      );
    }
    return RenderManifest(
      width: json['width']! as int,
      height: json['height']! as int,
      fps: json['fps']! as int,
      frameCount: json['frameCount']! as int,
      framesFileName: json['framesFileName']! as String,
      outputFileName: json['outputFileName']! as String,
      renderDigest: json['renderDigest']! as String,
      ffmpegArgs: (json['ffmpegArgs']! as List<Object?>).cast<String>(),
      posterArgs: (json['posterArgs'] as List<Object?>?)?.cast<String>(),
      posterFileName: json['posterFileName'] as String?,
    );
  }

  /// The manifest schema this library writes and reads.
  static const int schemaVersion = 1;

  /// Frame width in pixels.
  final int width;

  /// Frame height in pixels.
  final int height;

  /// Frames per second of the encode.
  final int fps;

  /// How many frames the frames file holds.
  final int frameCount;

  /// Sandbox-relative name of the raw RGBA frames file (`frames.rgba`).
  final String framesFileName;

  /// Sandbox-relative name of the encoded output (`out.mp4`).
  final String outputFileName;

  /// The render digest the frame cache keyed this capture under.
  final String renderDigest;

  /// The complete, validated ffmpeg encode argument array (unmodifiable);
  /// every file reference in it is sandbox-relative.
  final List<String> ffmpegArgs;

  /// The SECOND ffmpeg invocation extracting the poster still (unmodifiable),
  /// or `null` when the composition declares no `Video.poster`.
  final List<String>? posterArgs;

  /// Sandbox-relative name of the poster still (`poster.png`), or `null` when
  /// there is no poster.
  final String? posterFileName;

  /// The JSON form, with [schemaVersion] first. The poster keys appear only
  /// when a poster is present, so a no-poster manifest is byte-identical to a
  /// pre-poster one.
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'width': width,
    'height': height,
    'fps': fps,
    'frameCount': frameCount,
    'framesFileName': framesFileName,
    'outputFileName': outputFileName,
    'renderDigest': renderDigest,
    'ffmpegArgs': ffmpegArgs,
    if (posterArgs != null) 'posterArgs': posterArgs,
    if (posterFileName != null) 'posterFileName': posterFileName,
  };

  @override
  bool operator ==(Object other) =>
      other is RenderManifest &&
      other.width == width &&
      other.height == height &&
      other.fps == fps &&
      other.frameCount == frameCount &&
      other.framesFileName == framesFileName &&
      other.outputFileName == outputFileName &&
      other.renderDigest == renderDigest &&
      listEquals(other.ffmpegArgs, ffmpegArgs) &&
      listEquals(other.posterArgs, posterArgs) &&
      other.posterFileName == posterFileName;

  @override
  int get hashCode => Object.hash(
    width,
    height,
    fps,
    frameCount,
    framesFileName,
    outputFileName,
    renderDigest,
    Object.hashAll(ffmpegArgs),
    posterArgs == null ? null : Object.hashAll(posterArgs!),
    posterFileName,
  );
}
