import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show decodeTime;
import 'package:fluvie/rendering.dart' show MediaResolver, TimeScopeData, WebClipDecoder;
import 'package:fluvie_editor/src/canvas/editor_canvas.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/media/media_store_entry.dart';
import 'package:fluvie_editor/src/transport/slide_transport.dart';

/// A source-only composition driven by source-frame time, without changing the
/// open project or its selection. Decoding shares the program preview path.
final class SourceMediaPreview extends StatefulWidget {
  /// Shows an imported source at [frame] using the shared picture decoder.
  const SourceMediaPreview({
    required this.entry,
    required this.frame,
    this.clipDecoder,
    this.mediaResolver,
    this.maxClipEdge = 480,
    super.key,
  });

  /// The source asset, including its probed dimensions and marking rate.
  final MediaStoreEntry entry;

  /// The source-frame playhead, independent from timeline placement.
  final int frame;

  /// Browser decoder; native platforms use their normal resolver.
  final WebClipDecoder? clipDecoder;

  /// Optional caller-owned resolver, shared with hosted previews or tests.
  final MediaResolver? mediaResolver;

  /// Maximum decoded image edge for this small monitor.
  final int? maxClipEdge;

  @override
  State<SourceMediaPreview> createState() => _SourceMediaPreviewState();
}

final class _SourceMediaPreviewState extends State<SourceMediaPreview> {
  late EditorDocument _document;
  late SlideTransport _transport;

  void _create() {
    final asset = widget.entry;
    // The composition clock is integral; convert the source mark through time
    // to preserve fractional rates rather than rounding the source frame.
    final fps = (asset.fps ?? 30).ceil();
    final count = asset.durationFrames;
    final length = count == null
        ? decodeTime(asset.duration ?? '1s')
              .resolveFrames(TimeScopeData(fps: fps, startFrame: 0, durationFrames: fps))
              .clamp(1, 1 << 31)
        : _compositionFrame((count - 1).clamp(0, 1 << 31), fps) + 1;
    _document = EditorDocument.fromJson({
      'fluvieSpec': 1,
      'fps': fps,
      'size': {'width': asset.width ?? 640, 'height': asset.height ?? 360},
      'scenes': [
        {
          'duration': '${length}f',
          'layout': 'canvas',
          'children': [
            {
              'id': 'source-preview',
              'type': asset.kind == MediaStoreKind.video ? 'Clip' : 'Image',
              'source': asset.source,
              'fit': 'contain',
              'transform': const {'x': 0.5, 'y': 0.5, 'w': 1.0, 'h': 1.0},
            },
          ],
        },
      ],
    });
    _transport = SlideTransport(
      fps: fps,
      length: _document.spec.build().totalFrames,
      initialFrame: _frame(fps),
    );
  }

  // Choose a composition sample inside the requested source-frame interval.
  // The composition rate is at least the source rate, so every source frame
  // has a representable sample. A nearest-frame conversion can land before
  // the requested source frame at fractional rates (1 / 30 * 29.97 < 1).
  int _compositionFrame(int sourceFrame, int fps) =>
      (sourceFrame * fps / (widget.entry.fps ?? fps)).ceil();

  int _frame(int fps) {
    final count = widget.entry.durationFrames;
    final sourceFrame = count == null
        ? widget.frame.clamp(0, 1 << 31)
        : widget.frame.clamp(0, (count - 1).clamp(0, 1 << 31));
    return _compositionFrame(sourceFrame, fps);
  }

  @override
  void initState() {
    super.initState();
    _create();
  }

  @override
  void didUpdateWidget(SourceMediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.entry;
    final current = widget.entry;
    if (previous.id != current.id ||
        !mapEquals(previous.source, current.source) ||
        previous.kind != current.kind ||
        previous.fps != current.fps ||
        previous.duration != current.duration ||
        previous.width != current.width ||
        previous.height != current.height) {
      final retired = _transport;
      WidgetsBinding.instance.addPostFrameCallback((_) => retired.dispose());
      _create();
    } else {
      _transport.seek(_frame(_transport.fps));
    }
  }

  @override
  void dispose() {
    _transport.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EditorCanvas(
    document: _document,
    slide: 0,
    transport: _transport,
    clipDecoder: widget.clipDecoder,
    mediaResolver: widget.mediaResolver,
    previewMaxEdge: widget.maxClipEdge,
  );
}
