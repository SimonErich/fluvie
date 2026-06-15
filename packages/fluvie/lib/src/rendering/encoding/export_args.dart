/// Pure FFmpeg argument and filter builders for the non-MP4 [Export] modes:
/// GIF, image sequence, transparent WebM, and
/// the poster still. No new dependency rides along — every mode is native
/// FFmpeg (`palettegen`/`paletteuse`, `image2`, `libvpx-vp9`, `select`).
///
/// Each builder returns a **typed argument array** or a single validated
/// filter-graph string, never a shell string, and validates every file name so
/// an argument can neither escape the render sandbox nor be parsed as a flag.
/// The arrays are order-stable, so the encode-twice byte-equality tests hold.
library;

import 'package:fluvie/src/core/export.dart';

/// The default 6-digit image-sequence pattern for [format] (e.g.
/// `frame_%06d.png`). FFmpeg's `image2` muxer substitutes the running frame
/// index into the `%06d` token, zero-padded to six digits.
String imageSequenceName(ImageFormat format) => switch (format) {
  ImageFormat.png => 'frame_%06d.png',
};

/// The default sandbox-relative output name for [export] (or [Export.mp4]'s
/// `out.mp4` when `null`): the container/pattern each export variant writes.
String exportOutputName(Export? export) => switch (export?.mode) {
  null || ExportMode.mp4 => 'out.mp4',
  ExportMode.gif => 'out.gif',
  ExportMode.imageSequence => imageSequenceName(export!.imageFormat ?? ImageFormat.png),
  ExportMode.transparent => 'out.webm',
};

/// The single-graph two-pass palette `-filter_complex` value for a GIF sampled
/// at [fps]: downsample to [fps], scale to an even
/// size with Lanczos, then `palettegen`/`paletteuse` in one graph so the GIF
/// uses an optimized 256-color palette with Bayer dithering.
///
/// Throws an [ArgumentError] when [fps] is not positive.
String gifFilterComplex({required int fps}) {
  if (fps <= 0) {
    throw ArgumentError.value(fps, 'fps', 'must be positive');
  }
  return 'fps=$fps,scale=trunc(iw/2)*2:trunc(ih/2)*2:flags=lanczos,split[s0][s1];'
      '[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=bayer';
}

/// The GIF video options (no `-an`): the palette [gifFilterComplex] graph at
/// [fps] routed through `-filter_complex`. The builder appends `-an` and the
/// determinism quartet around these.
List<String> gifVideoOptions({required int fps}) => ['-filter_complex', gifFilterComplex(fps: fps)];

/// The GIF output options: the validated palette graph at [fps] plus `-an` (a
/// GIF carries no audio). The output [name] is appended by the caller.
List<String> gifOutputArgs({required String name, required int fps}) {
  validateFfmpegName(name, 'name');
  return [...gifVideoOptions(fps: fps), '-an'];
}

/// The image-sequence video options (no `-an`) for [format]: `-c:v png -f
/// image2`. The muxer writes one lossless still per frame for compositing.
List<String> imageSequenceVideoOptions(ImageFormat format) => switch (format) {
  ImageFormat.png => const ['-c:v', 'png', '-f', 'image2'],
};

/// The image-sequence output options, validating the `%0Nd` pattern [name]
/// (e.g. `frame_%06d.png`). The `image2` muxer writes silent stills, so unlike
/// the GIF/WebM modes it carries no `-an`.
List<String> imageSequenceOutputArgs({required String name, required ImageFormat format}) {
  validateFfmpegName(name, 'name', allowImagePattern: true);
  return imageSequenceVideoOptions(format);
}

/// The transparent-overlay video options (no `-an`): VP9 with a `yuva420p`
/// alpha plane and `-auto-alt-ref 0` (alt-ref frames drop the alpha plane).
///
/// The RGBA alpha captured per frame is preserved — this path deliberately
/// never forces `yuv420p` the way the MP4 path does (ProRes `.mov` is not yet
/// supported).
List<String> transparentVideoOptions() => const [
  '-c:v',
  'libvpx-vp9',
  '-pix_fmt',
  'yuva420p',
  '-auto-alt-ref',
  '0',
];

/// The transparent-overlay output options: the VP9/alpha codec options plus
/// `-an`. The output [name] is appended by the caller.
List<String> transparentOutputArgs({required String name}) {
  validateFfmpegName(name, 'name');
  return [...transparentVideoOptions(), '-an'];
}

/// The single-frame select filter for the poster still at [frameIndex]
/// (`select=eq(n\,K)`). FFmpeg keeps only the frame whose 0-based index equals
/// [frameIndex]; the comma is escaped so it stays inside the filter argument.
///
/// Throws an [ArgumentError] when [frameIndex] is negative.
String posterFilter(int frameIndex) {
  if (frameIndex < 0) {
    throw ArgumentError.value(frameIndex, 'frameIndex', 'must not be negative');
  }
  return 'select=eq(n\\,$frameIndex)';
}

/// The poster video options (no `-an`): the [posterFilter] for [frameIndex] as
/// `-vf` plus `-vframes 1` (keep exactly one frame). The builder appends `-an`
/// and the quartet around these.
List<String> posterVideoOptions(int frameIndex) => [
  '-vf',
  posterFilter(frameIndex),
  '-vframes',
  '1',
];

/// The complete poster-extract argument array: the
/// [posterVideoOptions] for [frameIndex], `-an`, then the validated poster
/// [name]. This is a SECOND ffmpeg output invocation over the same frames file,
/// so it carries its own output name.
List<String> posterOutputArgs({required String name, required int frameIndex}) {
  validateFfmpegName(name, 'name');
  return [...posterVideoOptions(frameIndex), '-an', name];
}

/// Rejects anything that is not a safe sandbox-relative file name: empty
/// names, names that would parse as a flag (leading `-`), and names with `/`
/// or `\` separators (covering `../` traversal and absolute paths).
///
/// When [allowImagePattern] is set, exactly one `%0Nd` token (e.g. `%06d`) is
/// permitted for the `image2` muxer — and no other `%`; otherwise any `%` is
/// rejected. This is the security boundary shared by the `FfmpegArgsBuilder`
/// and every builder above, so output names can never escape the render sandbox.
void validateFfmpegName(String name, String parameter, {bool allowImagePattern = false}) {
  if (name.isEmpty) {
    throw ArgumentError.value(name, parameter, 'must not be empty');
  }
  if (name.startsWith('-')) {
    throw ArgumentError.value(name, parameter, 'must not start with "-" (flag injection)');
  }
  if (name.contains('/') || name.contains(r'\')) {
    throw ArgumentError.value(
      name,
      parameter,
      'must be a bare sandbox-relative file name without path separators',
    );
  }
  _validatePercent(name, parameter, allowImagePattern: allowImagePattern);
}

/// Enforces the `%` policy: with [allowImagePattern] exactly one `%0Nd` token
/// and no other `%`; without it, no `%` at all.
void _validatePercent(String name, String parameter, {required bool allowImagePattern}) {
  final percentCount = '%'.allMatches(name).length;
  if (!allowImagePattern) {
    if (percentCount != 0) {
      throw ArgumentError.value(name, parameter, 'must not contain "%" (format-token injection)');
    }
    return;
  }
  if (percentCount != 1 || !_imagePattern.hasMatch(name)) {
    throw ArgumentError.value(
      name,
      parameter,
      'must contain exactly one zero-padded %0Nd image2 token (e.g. %06d)',
    );
  }
}

/// Exactly one zero-padded width token: a `%`, a `0`, one-plus digits, a `d`.
final RegExp _imagePattern = RegExp(r'%0\d+d');
