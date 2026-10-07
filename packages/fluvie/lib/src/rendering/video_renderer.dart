import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/rendering/render_progress.dart';

/// Renders a composition to [T] on one platform: a `File` where the encode
/// lands on disk (desktop, on-device mobile), bytes where it stays in memory
/// (the browser).
///
/// A shared host contract for `DesktopVideoRenderer`
/// (local FFmpeg), `OnDeviceVideoRenderer` in `fluvie_mobile_encoder` (the
/// platform's hardware encoder), and `WebVideoRenderer` in
/// `fluvie_web_encoder` (ffmpeg.wasm). They share the deterministic frame capture
/// loop; media decoding, audio support and export capabilities depend on the
/// backend. Implementations may add
/// platform extras as further optional named parameters (an output file, a
/// codec, an `Export` mode) and choose their own defaults.
// ignore: one_member_abstracts — the renderer family contract; three platform arms implement it.
abstract interface class VideoRenderer<T> {
  /// Renders [composition] for [aspect] over [duration] and returns the
  /// encoded result.
  ///
  /// [fps] and [duration] set the frame count; [longEdge] sets the canvas's
  /// longer side in pixels (the shorter side is derived from [aspect]).
  /// [audio] controls whether authored audio joins the encode. Its default is
  /// chosen by each implementation; desktop rendering currently enables it.
  /// Pass it explicitly when selecting a backend dynamically. When a
  /// composition declares audio the renderer drops, it warns once unless
  /// [warnOnDroppedAudio] is `false`. [onProgress] observes the capturing,
  /// encoding, and complete phases; [compositionKey] labels them.
  Future<T> render({
    required Widget composition,
    required Aspect aspect,
    required Duration duration,
    int fps,
    int longEdge,
    bool audio,
    bool warnOnDroppedAudio,
    String compositionKey,
    RenderProgressCallback? onProgress,
  });
}
