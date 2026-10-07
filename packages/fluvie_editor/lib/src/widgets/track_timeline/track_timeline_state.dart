part of 'track_timeline.dart';

// obers_ui upstream candidate (part of track_timeline.dart): the widget
// state — scroll, zoom wheel handling, the drag value types, and the frame
// of parts around it.

/// How a pointer grabbed a bar (or one of its diamonds).
enum _DragMode { move, resizeStart, resizeEnd, diamond }

/// One in-flight drag: the grabbed bar (and diamond) as they were when the
/// drag began (the baseline stays stable while the host re-renders
/// mid-drag) and the pixels travelled since.
final class _BarDrag {
  _BarDrag({required this.bar, required this.mode, this.diamond});

  final TimelineBar bar;
  final _DragMode mode;
  final TimelineDiamond? diamond;
  double travelled = 0;

  String get dragId => diamond?.id ?? bar.id;
}

/// A bar hit: the row's track, the bar, and how it was grabbed.
final class _BarHit {
  const _BarHit({required this.track, required this.bar, required this.mode});

  final TimelineTrack track;
  final TimelineBar bar;
  final _DragMode mode;
}

final class _TrackTimelineState extends State<TrackTimeline> with SingleTickerProviderStateMixin {
  late final TrackTimelineController _own = TrackTimelineController();

  /// The snap guide's flash. It rides a controller so tests drive it with
  /// pumped time rather than a wall clock, and it starts settled: a timeline
  /// that mounts with a guide already up has nothing to announce.
  ///
  /// Built in [initState] rather than lazily, or a timeline that never painted
  /// a lane would build its first ticker inside [dispose], where the element
  /// tree can no longer be asked for a [TickerMode].
  late final AnimationController _snapPulse;
  final FocusNode _lanesFocus = FocusNode(debugLabel: 'TrackTimeline lanes');
  double _scrollX = 0;
  double _scrollY = 0;
  Size _laneSize = Size.zero;

  /// Where each row sits, rebuilt with the visible tracks. Every surface that
  /// asks which lane a pixel belongs to reads this one answer.
  TimelineLaneRows _rows = TimelineLaneRows(tracks: const [], defaultHeight: 28);
  _BarDrag? _drag;
  _LinkDrag? _linkDrag;
  Offset? _marqueeAnchor;
  Rect? _marquee;
  _MarkerDrag? _markerDrag;
  double? _rangeDragAnchor;
  String? _hoverBarId;
  ({int from, int to})? _announcedSpan;
  int _lastRulerTapMs = 0;
  double _lastRulerTapDx = double.negativeInfinity;

  TrackTimelineController get _controller => widget.controller ?? _own;

  double get _pixelsPerFrame => _controller.pixelsPerFrame;

  /// [setState] for the gesture extensions (the member is protected).
  void _rebuild(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _snapPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(TrackTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new line to announce, not the loss of one: letting go of a snap is
    // the absence of an event, and flashing there would read as a catch.
    final frame = widget.snapFrame;
    if (frame != null && frame != oldWidget.snapFrame) _snapPulse.forward(from: 0);
  }

  @override
  void dispose() {
    _snapPulse.dispose();
    _lanesFocus.dispose();
    _own.dispose();
    super.dispose();
  }

  void _onWheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final delta = event.scrollDelta;
    if (HardwareKeyboard.instance.isControlPressed) {
      final box = context.findRenderObject()! as RenderBox;
      final double cursorDx = math.max(
        0,
        box.globalToLocal(event.position).dx - widget.appearance.labelWidth,
      );
      final from = _pixelsPerFrame;
      final to = (delta.dy < 0 ? from * 1.1 : from / 1.1).clamp(
        TrackTimelineController.minPixelsPerFrame,
        TrackTimelineController.maxPixelsPerFrame,
      );
      setState(() {
        _scrollX = _clampX(
          TrackTimelineController.zoomedScroll(
            scrollX: _scrollX,
            cursorDx: cursorDx,
            from: from,
            to: to,
          ),
          pixelsPerFrame: to,
        );
      });
      _controller.pixelsPerFrame = to;
    } else if (HardwareKeyboard.instance.isShiftPressed) {
      setState(() => _scrollY = _clampY(_scrollY + delta.dy));
    } else {
      setState(() => _scrollX = _clampX(_scrollX + delta.dy + delta.dx));
    }
  }

  double _clampX(double value, {double? pixelsPerFrame}) {
    final width = widget.totalFrames * (pixelsPerFrame ?? _pixelsPerFrame) + 24;
    final double max = math.max(0, width - _laneSize.width);
    return value.clamp(0, max);
  }

  double _clampY(double value) {
    final double max = math.max(0, _rows.totalHeight - _laneSize.height);
    return value.clamp(0, max);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      if (widget.tracks.isEmpty) return _emptyState(context);
      final colors = context.colors;
      final visible = TrackTimelineController.visibleTracks(widget.tracks, _controller.collapsed);
      _rows = TimelineLaneRows(tracks: visible, defaultHeight: widget.appearance.trackHeight);
      return ColoredBox(
        color: colors.surface,
        child: Listener(
          onPointerSignal: _onWheel,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: widget.appearance.labelWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: widget.appearance.rulerHeight),
                    Expanded(child: ClipRect(child: _labelsColumn(context, visible))),
                  ],
                ),
              ),
              Expanded(child: _lanes(context, visible)),
            ],
          ),
        ),
      );
    },
  );
}
