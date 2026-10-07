import 'package:fluvie/fluvie.dart' show Aspect, VideoSpec;
import 'package:fluvie/rendering.dart' show RenderCancellation;
import 'package:slides/editor/deck_render_service_io.dart'
    if (dart.library.js_interop) 'package:slides/editor/deck_render_service_web.dart';
import 'package:slides/editor/export_options.dart';

export 'package:slides/editor/export_options.dart';

/// Renders the open deck to a video file through fluvie's render pipeline.
///
/// The desktop app renders through an off-screen capture surface plus a local
/// FFmpeg; the web build renders in the browser through ffmpeg.wasm when the
/// page ships the bridge, and otherwise reports itself unavailable — the
/// export menu then shows [unavailableNote] instead of hiding the entry.
abstract interface class DeckRenderService {
  /// The renderer for the running platform.
  factory DeckRenderService.platform() => platformDeckRenderService();

  /// Whether this platform can render right now. False on a web page without
  /// the ffmpeg.wasm bridge, where the menu item explains what is missing.
  bool get isAvailable;

  /// Why rendering is unavailable, phrased for the disabled menu entry
  /// (`Export video (<note>)`). Read only when [isAvailable] is false.
  String get unavailableNote;

  /// Picks an output file, renders [spec] at [options], and writes the video
  /// there.
  ///
  /// [suggestedName] seeds the output dialog. [options] is what this one run
  /// encodes at; it defaults to the deck's own canvas, frame rate and the
  /// pipeline's default quality, so a caller that does not care passes
  /// nothing. [onProgress] hears human phase lines ("Capturing frames",
  /// "Encoding") for a progress dialog. Returns the written path, or null when
  /// the user cancelled the pick. Render failures throw; the caller surfaces
  /// them.
  Future<String?> renderToVideo({
    required VideoSpec spec,
    required String suggestedName,
    ExportOptions? options,
    RenderCancellation? cancellation,
    void Function(String phase)? onProgress,
  });
}

/// The aspect family whose canvas matches a spec of [width] x [height]:
/// wide is landscape, square is square, and a tall canvas takes the nearer
/// of 4:5 and 9:16. The canonical sizes (1920x1080, 1080x1920, 1080x1350,
/// square) reproduce exactly; anything else renders at its family's size.
Aspect aspectForSize(int width, int height) {
  if (width == height) return Aspect.square;
  if (width > height) return Aspect.landscape;
  final ratio = width / height;
  return (ratio - 4 / 5).abs() <= (ratio - 9 / 16).abs() ? Aspect.portrait45 : Aspect.reels;
}

/// The wall-clock length of [frames] at [fps], rounded so that
/// `frameCountFor` derives exactly [frames] back from it.
Duration renderDurationFor(int frames, int fps) =>
    Duration(microseconds: (frames * Duration.microsecondsPerSecond / fps).round());
