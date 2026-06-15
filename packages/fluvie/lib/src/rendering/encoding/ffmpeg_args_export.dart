part of 'ffmpeg_args.dart';

/// The non-MP4 export-mode output setters and the poster setter for
/// [FfmpegArgsBuilder].
///
/// Each mirrors [FfmpegArgsBuilder.setH264Output]: it records one validated
/// output name (a second output setter throws [StateError]), sets the mode's
/// video options from the pure `export_args.dart` builders, and carries no
/// audio — `build` appends `-an`, the bitexact determinism quartet and
/// `-threads 1` exactly as for the MP4 path. None emit `-y`.
extension FfmpegArgsExportOutputs on FfmpegArgsBuilder {
  /// Sets an animated-GIF output written to the sandbox-relative [name],
  /// sampled at [fps] through the single-graph two-pass palette filter
  /// (native FFmpeg, no gif dependency).
  void setGifOutput({required String name, required int fps}) {
    _beginOutput(name);
    _outputOptions = gifVideoOptions(fps: fps);
  }

  /// Sets a lossless image-sequence output written to the `%0Nd` pattern
  /// [name] (e.g. `frame_%06d.png`) in [format] at [fps] via the `image2`
  /// muxer — one still per frame for compositing pipelines.
  void setImageSequenceOutput({
    required String name,
    required ImageFormat format,
    required int fps,
  }) {
    _beginOutput(name, allowImagePattern: true);
    _outputOptions = [...imageSequenceVideoOptions(format), '-r', '$fps'];
  }

  /// Sets a transparent-overlay WebM output written to the sandbox-relative
  /// [name] at [fps]: VP9 with a `yuva420p` alpha plane (the RGBA alpha is
  /// preserved, never forced to yuv420p).
  void setTransparentOutput({required String name, required int fps}) {
    _beginOutput(name);
    _outputOptions = [...transparentVideoOptions(), '-r', '$fps'];
  }

  /// Sets a single-frame poster PNG written to the sandbox-relative [name],
  /// selecting the frame at [frameIndex]. This is
  /// the SECOND output invocation over the same frames file, declared as its
  /// own builder; [fps] declares the raw input rate the select filter counts
  /// frames against.
  void setPosterOutput({required String name, required int frameIndex, required int fps}) {
    _beginOutput(name);
    _outputOptions = [...posterVideoOptions(frameIndex), '-r', '$fps'];
  }
}
