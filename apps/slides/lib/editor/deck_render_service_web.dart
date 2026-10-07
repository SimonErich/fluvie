import 'dart:typed_data';

import 'package:fluvie/fluvie.dart' show VideoSpec;
import 'package:fluvie/rendering.dart' show RenderCancellation;
import 'package:fluvie/rendering.dart' show RenderPhase, RenderProgress, VideoRenderer;
import 'package:fluvie_web_encoder/fluvie_web_encoder.dart' show WebVideoRenderer, downloadBytes;
import 'package:slides/editor/deck_render_service.dart';
import 'package:slides/editor/web_export_capability.dart';

/// The web renderer: fluvie's capture loop plus ffmpeg.wasm, fully in the
/// browser, available whenever the page ships the `FluvieFfmpeg` bridge.
DeckRenderService platformDeckRenderService() => WebDeckRenderService();

/// Delivers rendered [bytes] to the user as [filename] (a browser download).
typedef RenderedBytesSink = Future<void> Function(Uint8List bytes, String filename);

/// [DeckRenderService] for the web build: renders the spec-built `Video`
/// through `WebVideoRenderer` with audio enabled — the same composition the
/// desktop path renders — and delivers the MP4 as a browser download.
///
/// Availability is an honest runtime probe: without the ffmpeg.wasm bridge in
/// `index.html` the service reports itself unavailable and the export menu
/// explains what is missing instead of offering a dead button.
final class WebDeckRenderService implements DeckRenderService {
  /// Creates the service; the defaults target a real browser page. Tests
  /// inject `createRenderer`, [deliver], and [bridgeProbe].
  WebDeckRenderService({
    this._createRenderer,
    RenderedBytesSink? deliver,
    bool Function()? bridgeProbe,
  }) : _deliver = deliver ?? _download,
       _bridgeProbe = bridgeProbe ?? hasFfmpegBridge;

  final VideoRenderer<Uint8List> Function()? _createRenderer;
  final RenderedBytesSink _deliver;
  final bool Function() _bridgeProbe;

  @override
  bool get isAvailable => _bridgeProbe();

  @override
  String get unavailableNote => 'needs the ffmpeg.wasm bridge in index.html';

  @override
  Future<String?> renderToVideo({
    required VideoSpec spec,
    required String suggestedName,
    ExportOptions? options,
    RenderCancellation? cancellation,
    void Function(String phase)? onProgress,
  }) async {
    cancellation?.throwIfCancelled();
    final run = options ?? ExportOptions.forSpec(spec);
    final video = run.applyTo(spec).build();
    // The aspect family stays the deck's; only the long edge scales.
    final aspect = aspectForSize(spec.size.width, spec.size.height);
    final longEdge = run.longEdge;
    final renderer = _createRenderer?.call() ?? WebVideoRenderer(cancellation: cancellation);
    final bytes = await renderer.render(
      composition: video,
      aspect: aspect,
      duration: renderDurationFor(video.totalFrames, spec.fps),
      fps: spec.fps,
      longEdge: longEdge,
      audio: true,
      onProgress: (progress) {
        cancellation?.throwIfCancelled();
        onProgress?.call(_phaseLine(progress));
      },
    );
    cancellation?.throwIfCancelled();
    await _deliver(bytes, suggestedName);
    return suggestedName;
  }

  /// The human phase line for the progress dialog, frame counts included
  /// while capturing.
  static String _phaseLine(RenderProgress progress) => switch (progress.phase) {
    RenderPhase.capturing when progress.completedFrames != null && progress.totalFrames != null =>
      'Capturing frame ${progress.completedFrames} of ${progress.totalFrames}',
    RenderPhase.capturing => 'Capturing frames',
    RenderPhase.encoding => 'Encoding (ffmpeg.wasm)',
    RenderPhase.complete => 'Finishing',
  };

  // coverage:ignore-start browser only defaults the real encoder and the Blob
  // download need a live page so tests inject both seams

  static Future<void> _download(Uint8List bytes, String filename) async =>
      downloadBytes(bytes, filename: filename);
  // coverage:ignore-end
}
