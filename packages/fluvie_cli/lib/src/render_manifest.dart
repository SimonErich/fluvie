import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';

/// The CLI-side view of the capture sandbox's `manifest.json`: the CLI
/// validates it and spawns ffmpeg with exactly [ffmpegArgs] — it never
/// composes encode arguments itself.
final class RenderManifest {
  RenderManifest._({
    required this.frameCount,
    required this.framesFileName,
    required this.outputFileName,
    required this.ffmpegArgs,
    this.posterArgs,
    this.posterFileName,
  });

  /// Parses a manifest, rejecting unknown schema versions and malformed
  /// fields with a [CliFailure].
  factory RenderManifest.fromJson(Map<String, Object?> json) {
    final version = json['schemaVersion'];
    if (version != supportedSchemaVersion) {
      throw CliFailure(
        'Unsupported manifest schemaVersion "$version" (this CLI reads version '
        '$supportedSchemaVersion). The capture harness and the CLI must run '
        'matching fluvie versions.',
      );
    }
    final frameCount = json['frameCount'];
    final framesFileName = json['framesFileName'];
    final outputFileName = json['outputFileName'];
    final args = json['ffmpegArgs'];
    final posterArgs = json['posterArgs'];
    final posterFileName = json['posterFileName'];
    if (frameCount is! int ||
        framesFileName is! String ||
        outputFileName is! String ||
        args is! List<Object?> ||
        args.any((arg) => arg is! String) ||
        (posterArgs != null &&
            (posterArgs is! List<Object?> || posterArgs.any((a) => a is! String))) ||
        (posterFileName != null && posterFileName is! String)) {
      throw const CliFailure(
        'Malformed manifest.json: one of frameCount, framesFileName, '
        'outputFileName, ffmpegArgs, posterArgs is missing or has the wrong type.',
      );
    }
    return RenderManifest._(
      frameCount: frameCount,
      framesFileName: framesFileName,
      outputFileName: outputFileName,
      ffmpegArgs: List.unmodifiable(args.cast<String>()),
      posterArgs: posterArgs == null
          ? null
          : List<String>.unmodifiable((posterArgs as List<Object?>).cast<String>()),
      posterFileName: posterFileName as String?,
    );
  }

  /// Reads and parses `manifest.json` from [sandbox].
  ///
  /// A missing manifest means the capture step died before its completion
  /// signal — reported as a capture failure, not a JSON error.
  factory RenderManifest.read(Directory sandbox) {
    final file = File('${sandbox.path}/manifest.json');
    if (!file.existsSync()) {
      throw CliFailure(
        'The capture step finished without writing manifest.json into '
        '${sandbox.path} — the capture failed before completing its frames.',
      );
    }
    final Object? json;
    try {
      json = jsonDecode(file.readAsStringSync());
    } on FormatException catch (error) {
      throw CliFailure('manifest.json is not valid JSON: ${error.message}');
    }
    if (json is! Map<String, Object?>) {
      throw const CliFailure('manifest.json does not hold a JSON object.');
    }
    return RenderManifest.fromJson(json);
  }

  /// The manifest schema this CLI understands.
  static const int supportedSchemaVersion = 1;

  /// How many frames the frames file holds.
  final int frameCount;

  /// Sandbox-relative name of the raw frames file.
  final String framesFileName;

  /// Sandbox-relative name of the encoded output.
  ///
  /// For single-file modes (mp4/gif/transparent) this is a bare file name such
  /// as `out.mp4`. For the image-sequence export it is the `image2` muxer
  /// pattern `frame_%06d.png`, which ffmpeg expands into one still per frame —
  /// never a file that exists literally on disk. [isImageSequence] tells the
  /// two apart.
  final String outputFileName;

  /// Whether [outputFileName] is an `image2` frame pattern (it carries a
  /// `%0Nd` printf token) rather than a single concrete output file.
  ///
  /// This is the signal the encode step branches on: a single-file mode moves
  /// one output file to `--out`, the image-sequence mode collects every
  /// produced still into the `--out` directory. The `%` is the only token the
  /// validated pattern may contain.
  bool get isImageSequence => _imagePattern.hasMatch(outputFileName);

  /// The literal `(prefix, suffix)` around the `%0Nd` token of
  /// [outputFileName] — e.g. `('frame_', '.png')` for `frame_%06d.png`. The
  /// encode step matches the produced stills by these literal bounds.
  ///
  /// Throws a [StateError] when the name is not an image-sequence pattern;
  /// guard with [isImageSequence] first.
  ({String prefix, String suffix}) get imageSequenceBounds {
    final match = _imagePattern.firstMatch(outputFileName);
    if (match == null) {
      throw StateError('outputFileName "$outputFileName" is not an image2 pattern');
    }
    return (
      prefix: outputFileName.substring(0, match.start),
      suffix: outputFileName.substring(match.end),
    );
  }

  /// One zero-padded `image2` width token: a `%`, a `0`, one-plus digits, a
  /// `d`. Mirrors the library's `validateFfmpegName` image-pattern rule so the
  /// CLI and harness agree on exactly which names are sequence patterns.
  static final RegExp _imagePattern = RegExp(r'%0\d+d');

  /// The complete encode argument array (unmodifiable), spawned verbatim.
  final List<String> ffmpegArgs;

  /// The SECOND poster-extract argument array (unmodifiable), spawned verbatim
  /// after [ffmpegArgs], or `null` when the composition declares no poster.
  final List<String>? posterArgs;

  /// Sandbox-relative name of the poster still, or `null` when there is none.
  final String? posterFileName;

  /// Rejects any token that could reach outside [sandbox]: absolute paths,
  /// Windows drive paths, ffmpeg protocol URLs (`file:`, `http:`, `concat:`,
  /// `pipe:`, ...), and `..` path segments — in [ffmpegArgs] and [posterArgs]
  /// as well as every file name (which additionally must be bare,
  /// separator-free names).
  void validateSandboxConfinement(Directory sandbox) {
    for (final name in [framesFileName, outputFileName, ?posterFileName]) {
      if (name.isEmpty || name.contains('/') || name.contains(r'\') || name.startsWith('-')) {
        throw CliFailure(
          'Manifest file name "$name" is not a bare sandbox-relative file '
          'name; refusing to encode from ${sandbox.path}.',
        );
      }
    }
    for (final token in [...ffmpegArgs, ...?posterArgs]) {
      if (_escapesSandbox(token)) {
        throw CliFailure(
          'Manifest ffmpeg argument "$token" would escape the render sandbox '
          '${sandbox.path}; refusing to run ffmpeg.',
        );
      }
    }
  }

  /// An ffmpeg protocol-URL prefix (`file:`, `http:`, `concat:`, `pipe:`,
  /// ...). Two-plus characters before the colon keep single-letter Windows
  /// drive paths in the dedicated drive-path rule; flag/filter tokens like
  /// `-map`, `0:v:0` or `format=yuv420p` never match (no leading letter, or a
  /// non-scheme character before the first colon).
  static final RegExp _protocolUrl = RegExp('^[A-Za-z][A-Za-z0-9+.-]+:');

  static bool _escapesSandbox(String token) {
    if (token.startsWith('/') || token.startsWith(r'\')) return true;
    if (RegExp(r'^[A-Za-z]:[/\\]').hasMatch(token)) return true;
    if (_protocolUrl.hasMatch(token)) return true;
    return token.split(RegExp(r'[/\\]')).contains('..');
  }
}
