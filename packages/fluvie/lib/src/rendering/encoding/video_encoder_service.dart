import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/rendering/encoding/audio_graph_nodes.dart';
import 'package:fluvie/src/rendering/encoding/export_args.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_args.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_filter_graph_builder.dart';
import 'package:fluvie/src/rendering/render_config.dart';

/// Plans the encode of a captured frames file to the requested [Export] mode.
///
/// This is **pure and `dart:io`-free** so it runs on every platform (the web
/// path reuses the same plan). [planEncodeArgs] embeds the complete argument
/// array in the render manifest, and the CLI later spawns ffmpeg with exactly
/// that plan — one source of ffmpeg-arg truth. With an `export` mode the plan
/// dispatches to GIF, image sequence, or transparent WebM; `null` and
/// [Export.mp4] keep the byte-identical H.264 path. A `posterFrame` adds a
/// SECOND poster-extract invocation via [planPosterArgs]. The in-process
/// `encode` convenience that runs a plan through an `FfmpegRunner` lives in
/// the `dart:io` extension `VideoEncoderServiceIo`.
final class VideoEncoderService {
  /// Creates the service; it is stateless and const.
  const VideoEncoderService();

  /// Sandbox-relative name of the raw RGBA8888 input stream.
  static const String framesFileName = 'frames.rgba';

  /// Sandbox-relative `image2` pattern for the PNG frame sequence — the
  /// bounded-memory web input where each frame is its own small PNG file
  /// (`frame_000000.png`, `frame_000001.png`, …) instead of one raw buffer.
  static const String framesPngPattern = 'frame_%06d.png';

  /// The sandbox file name of the PNG frame at zero-based [index], matching
  /// [framesPngPattern]'s six-digit zero-padded numbering.
  static String framesPngName(int index) => 'frame_${index.toString().padLeft(6, '0')}.png';

  /// Sandbox-relative name of the encoded MP4 output (the default container).
  static const String outputFileName = 'out.mp4';

  /// Sandbox-relative name of the extracted poster still.
  static const String posterFileName = 'poster.png';

  /// The sandbox-relative output name [planEncodeArgs] writes for [export]
  /// (`out.mp4` for `null`/[Export.mp4], `out.gif`, the `%0Nd` image pattern,
  /// or `out.webm`).
  String outputNameFor(Export? export) => exportOutputName(export);

  /// The complete ffmpeg argument array encoding [framesFileName] to the
  /// per-[export] output per [config], with optional [audio] lanes combined by
  /// an optional [amix] mixdown.
  ///
  /// The [audio]/[amix] pair is the rendering audio contract, not the audio
  /// layer's `AudioMixPlan` type, so this entry never depends on the audio
  /// feature; the
  /// caller destructures a plan into these two seam values. Non-MP4 export
  /// modes carry no audio. Pure and deterministic: equal inputs produce an
  /// equal array.
  /// Set [framesArePng] for the bounded-memory web path: the input is the
  /// [framesPngPattern] PNG sequence instead of the raw [framesFileName] stream.
  /// The desktop/mobile/server paths leave it `false` (raw RGBA), byte-identical
  /// to before.
  List<String> planEncodeArgs(
    RenderConfig config, {
    List<FfmpegAudioNode> audio = const [],
    FfmpegAudioMix? amix,
    Export? export,
    bool framesArePng = false,
  }) {
    final builder = FfmpegArgsBuilder();
    _addFramesInput(builder, config, framesArePng: framesArePng);
    _setOutput(builder, config, export: export, audio: audio, amix: amix);
    return builder.build();
  }

  /// Adds the captured-frames input to [builder]: the [framesPngPattern] PNG
  /// sequence when [framesArePng], else the raw RGBA [framesFileName] stream.
  void _addFramesInput(
    FfmpegArgsBuilder builder,
    RenderConfig config, {
    required bool framesArePng,
  }) {
    if (framesArePng) {
      builder.addImageSequenceInput(pattern: framesPngPattern, fps: config.fps);
    } else {
      builder.addRawVideoInput(
        name: framesFileName,
        width: config.width,
        height: config.height,
        fps: config.fps,
      );
    }
  }

  /// Dispatches the right output setter on [builder] for [export]'s mode.
  void _setOutput(
    FfmpegArgsBuilder builder,
    RenderConfig config, {
    required Export? export,
    required List<FfmpegAudioNode> audio,
    required FfmpegAudioMix? amix,
  }) {
    final name = exportOutputName(export);
    switch (export?.mode) {
      case null || ExportMode.mp4:
        builder.setH264Output(
          name: name,
          quality: export?.quality ?? config.quality,
          fps: config.fps,
          filters: const FfmpegFilterGraphBuilder().forFrames(
            width: config.width,
            height: config.height,
          ),
          audio: audio,
          amix: amix,
        );
      case ExportMode.gif:
        builder.setGifOutput(name: name, fps: export!.gifFps ?? 15);
      case ExportMode.imageSequence:
        builder.setImageSequenceOutput(
          name: name,
          format: export!.imageFormat ?? ImageFormat.png,
          fps: config.fps,
        );
      case ExportMode.transparent:
        builder.setTransparentOutput(name: name, fps: config.fps);
    }
  }

  /// The ffmpeg argument array for the SECOND poster invocation: reads
  /// [framesFileName] and writes one frame at
  /// [posterFrame] to [posterFileName]. Pure and deterministic.
  List<String> planPosterArgs(
    RenderConfig config, {
    required int posterFrame,
    bool framesArePng = false,
  }) {
    final builder = FfmpegArgsBuilder();
    _addFramesInput(builder, config, framesArePng: framesArePng);
    builder.setPosterOutput(name: posterFileName, frameIndex: posterFrame, fps: config.fps);
    return builder.build();
  }
}
