import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' as f;
import 'package:fluvie/rendering.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

/// Resolves a bounded number of visible thumbnails at a small decode tier.
/// It uses the same trim/speed resampler as the picture and never writes a spec.
final class TimelineFilmstrips extends ChangeNotifier {
  /// Creates a loader using the browser decoder or an optional borrowed resolver.
  TimelineFilmstrips({this.clipDecoder, this.resolver});

  /// Browser decoding bridge; native hosts use FFmpeg.
  final WebClipDecoder? clipDecoder;

  /// Caller-owned resolver, useful for a shared cache or deterministic tests.
  final MediaResolver? resolver;
  Map<String, List<TimelineThumbnail>> _thumbnails = const {};

  /// Borrowed images keyed by stable timeline bar identity.
  Map<String, List<TimelineThumbnail>> get thumbnails => _thumbnails;
  String? _error;

  /// Last extraction failure, suitable for an actionable preview notice.
  String? get error => _error;
  bool _disposed = false;
  bool _busy = false;
  String? _key;
  ({EditorDocument document, int from, int to})? _pending;
  final List<ui.Image> _images = [];

  ({EditorDocument document, int from, int to})? _lastRequest;

  /// Repeats the last visible-range request after a source or decoder recovers.
  void retry() {
    final last = _lastRequest;
    if (last == null || _disposed) return;
    _key = null;
    request(last.document, last.from, last.to);
  }

  /// Schedules at most 32 thumbnails across the currently visible range.
  void request(EditorDocument document, int from, int to) {
    final key = '${document.renderDigest}:$from:$to';
    if (_disposed || key == _key) return;
    _key = key;
    _pending = _lastRequest = (document: document, from: from, to: to);
    if (!_busy) unawaited(_load());
  }

  Future<void> _load() async {
    _busy = true;
    try {
      while (!_disposed && _pending != null) {
        final request = _pending!;
        _pending = null;
        final scope = resolverScope(
          resolver,
          clipDecoder: clipDecoder,
          clipDecodeMaxEdge: 160,
          streamClipFrames: false,
        );
        final output = <String, List<TimelineThumbnail>>{};
        final nextImages = <ui.Image>[];
        try {
          final model = VideoLaneModel.build(document: request.document);
          final bindings = <({String bar, String id, f.FrameSpan window})>[
            for (final entry in model.elementBars.entries)
              (bar: entry.key, id: entry.value.elementId, window: entry.value.window),
            for (final entry in model.overlayBars.entries)
              (bar: entry.key, id: entry.value.elementId, window: entry.value.window),
          ];
          var budget = 32;
          for (final binding in bindings) {
            if (_disposed || _pending != null || budget <= 0) break;
            final json = request.document.elementJson(binding.id);
            if (json?['type'] != 'Clip' ||
                binding.window.end <= request.from ||
                binding.window.start >= request.to) {
              continue;
            }
            // Build just this source through the real codec, including bundle
            // and relative-file resolution. Its timing comes from the model.
            final video = f.VideoSpec.fromJson({
              'fluvieSpec': 1,
              'fps': request.document.spec.fps,
              'size': {'width': 160, 'height': 90},
              'scenes': [
                {
                  'duration': '${binding.window.durationFrames}f',
                  'children': [
                    {
                      'type': 'Clip',
                      'source': json!['source'],
                      if (json['trim'] != null) 'trim': json['trim'],
                      if (json['speed'] != null) 'speed': json['speed'],
                    },
                  ],
                },
              ],
            }).build();
            final plan = collectClipPlans(
              video.scenes,
              video.fps,
              sceneStartFrames: video.sceneStartFrames,
              totalFrames: video.totalFrames,
            ).single;
            await scope.resolver.preResolveAll([plan.source]);
            final meta = await scope.resolver.probeClip(plan.source);
            final trim = resolveClipTrimBounds(plan.trim, meta);
            final offsets = resolveClipTrimOffsets(plan.trim, meta);
            final start = binding.window.start.clamp(request.from, request.to);
            final end = binding.window.end.clamp(request.from, request.to);
            final count = (end - start).clamp(1, 6);
            final thumbs = <TimelineThumbnail>[];
            for (var i = 0; i < count && budget > 0; i++, budget--) {
              if (_disposed || _pending != null) break;
              final frame = start + ((end - start - 1) * i / (count > 1 ? count - 1 : 1)).round();
              final sourceFrame = resampleClipFrame(
                compFrame: frame,
                windowStart: binding.window.start,
                compFps: request.document.spec.fps,
                srcFps: meta.fps,
                trimStartFrames: trim.start,
                trimEndFrames: trim.end,
                trimStartOffsetFrames: offsets.start - trim.start,
                trimEndOffsetFrames: offsets.end - trim.end,
                speed: plan.speed,
                sourceTimeMap: plan.sourceTimeMap,
              );
              await scope.resolver.preResolveClip(plan.source, [sourceFrame]);
              final image = scope.resolver.decodedClipFrame(plan.source, sourceFrame).clone();
              nextImages.add(image);
              thumbs.add(TimelineThumbnail(frame.toDouble(), image));
            }
            output[binding.bar] = thumbs;
          }
          if (_disposed || _pending != null) {
            for (final image in nextImages) {
              image.dispose();
            }
          } else {
            final retired = List<ui.Image>.of(_images);
            _images
              ..clear()
              ..addAll(nextImages);
            _thumbnails = output;
            _error = null;
            notifyListeners();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              for (final image in retired) {
                image.dispose();
              }
            });
          }
        } on Object catch (error) {
          for (final image in nextImages) {
            image.dispose();
          }
          if (!_disposed && _pending == null) {
            _error = 'Filmstrip unavailable: $error';
            notifyListeners();
          }
        } finally {
          await scope.dispose();
        }
      }
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pending = null;
    for (final image in _images) {
      image.dispose();
    }
    _images.clear();
    // An in-flight request releases its resolver in finally.
    super.dispose();
  }
}
