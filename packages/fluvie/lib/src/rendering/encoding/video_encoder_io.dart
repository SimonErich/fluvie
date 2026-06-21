import 'dart:io';

import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/rendering/encoding/audio_graph_nodes.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_provider.dart';
import 'package:fluvie/src/rendering/encoding/video_encoder_service.dart';
import 'package:fluvie/src/rendering/render_config.dart';

/// The in-process encode convenience for [VideoEncoderService].
///
/// Runs a planned argument array through an [FfmpegProvider] against a `dart:io`
/// [Directory] sandbox. It lives here, in a `dart:io` extension, so
/// [VideoEncoderService] itself stays pure and web-safe.
extension VideoEncoderServiceIo on VideoEncoderService {
  /// Encodes the frames already captured into [sandbox] by running
  /// [VideoEncoderService.planEncodeArgs] through [provider].
  ///
  /// The [audio] lanes and their optional [amix] mixdown thread straight into
  /// the plan, so a real (filter-chained) track encodes through
  /// `-filter_complex` instead of tripping the unmixed-track guard. With an
  /// [export] the plan dispatches to that mode. Failures surface as
  /// `FluvieEncodeException` from the provider.
  Future<void> encode({
    required RenderConfig config,
    required Directory sandbox,
    required FfmpegProvider provider,
    List<FfmpegAudioNode> audio = const [],
    FfmpegAudioMix? amix,
    Export? export,
  }) => provider.encode(
    args: planEncodeArgs(config, audio: audio, amix: amix, export: export),
    sandbox: sandbox,
  );
}
