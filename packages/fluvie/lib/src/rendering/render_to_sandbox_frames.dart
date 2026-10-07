part of 'render_to_sandbox.dart';

Future<void> _captureSandboxFrames({
  required RenderConfig config,
  required String digest,
  required FramePump pump,
  required GlobalKey boundaryKey,
  required FrameCaptureService capture,
  required RenderSandbox sandbox,
  FrameEncoder? frameEncoder,
  ProgressCallback? onProgress,
  RenderCancellation? cancellation,
}) async {
  final framesArePng = frameEncoder != null;
  if (framesArePng) {
    await runFrameCaptureLoop(
      config: config,
      cancellation: cancellation,
      digest: digest,
      pump: pump,
      boundaryKey: boundaryKey,
      capture: capture,
      onFrame: (raw) async {
        final png = await frameEncoder(raw.rgba, raw.width, raw.height);
        await sandbox.writeBytes(
          VideoEncoderService.framesPngName(raw.frameIndex - config.startFrame),
          png,
        );
      },
      onProgress: onProgress,
    );
  } else {
    final sink = sandbox.openFrames(VideoEncoderService.framesFileName);
    try {
      await runFrameCaptureLoop(
        config: config,
        cancellation: cancellation,
        digest: digest,
        pump: pump,
        boundaryKey: boundaryKey,
        sink: sink,
        capture: capture,
        onProgress: onProgress,
      );
    } finally {
      await sink.close();
    }
  }
}
