part of 'render_to_sandbox.dart';

RenderManifest _sandboxManifest({
  required RenderConfig config,
  required VideoEncoderService encoder,
  required bool framesArePng,
  required String digest,
  required Export? resolvedExport,
  required AudioMixPlan? audioPlan,
  required int? resolvedPoster,
}) {
  return RenderManifest(
    width: config.width,
    height: config.height,
    fps: config.fps,
    frameCount: config.frameCount,
    framesFileName: framesArePng
        ? VideoEncoderService.framesPngPattern
        : VideoEncoderService.framesFileName,
    outputFileName: encoder.outputNameFor(resolvedExport),
    renderDigest: digest,
    outputIntent: renderOutputIntent(config, resolvedExport, hasAudio: audioPlan?.amix != null),
    ffmpegArgs: encoder.planEncodeArgs(
      config,
      audio: audioPlan?.tracks ?? const [],
      amix: audioPlan?.amix,
      export: resolvedExport,
      framesArePng: framesArePng,
    ),
    posterFileName: resolvedPoster == null ? null : VideoEncoderService.posterFileName,
    posterArgs: resolvedPoster == null
        ? null
        : encoder.planPosterArgs(config, posterFrame: resolvedPoster, framesArePng: framesArePng),
  );
}
