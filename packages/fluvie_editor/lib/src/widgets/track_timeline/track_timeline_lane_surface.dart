part of 'track_timeline.dart';

/// The lanes' input stack and paint, with lifecycle owned by [state].
final class _TimelineLaneSurface extends StatelessWidget {
  const _TimelineLaneSurface({
    required this.state,
    required this.visible,
    required this.colors,
    required this.labelStyle,
  });

  final _TrackTimelineState state;
  final List<TimelineTrack> visible;
  final OiColorScheme colors;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    return DragTarget<Object>(
      onWillAcceptWithDetails: (_) =>
          state.widget.edit.onForeignDrop != null || state.widget.edit.onForeignLaneDrop != null,
      onAcceptWithDetails: (details) => state._foreignDrop(details, visible),
      builder: (context, _, _) => Focus(
        focusNode: state._lanesFocus,
        onKeyEvent: state._onLanesKey,
        child: MouseRegion(
          onHover: (event) => state._hover(event.localPosition, visible),
          onExit: (_) => state._hover(null, visible),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onTapUp: (details) => state._laneTap(details.localPosition, visible),
            onHorizontalDragStart: (details) => state._dragStart(details.localPosition, visible),
            onHorizontalDragUpdate: (details) => state._dragUpdate(details, visible),
            onHorizontalDragEnd: (_) => state._dragEnd(visible),
            onHorizontalDragCancel: () => state._dragEnd(visible),
            child: ClipRect(
              child: CustomPaint(
                size: Size.infinite,
                painter: _LanesPainter(
                  tracks: visible,
                  selectedTrackIds: state.widget.selection.selectedTrackIds,
                  rows: state._rows,
                  pixelsPerFrame: state._pixelsPerFrame,
                  scrollX: state._scrollX,
                  scrollY: state._scrollY,
                  totalFrames: state.widget.totalFrames,
                  playhead: state.widget.playhead,
                  range: state.widget.selection.rangeSelection,
                  selectedBarIds: state.widget.selection.selectedBarIds,
                  marquee: state._marquee,
                  snapFrame: state.widget.snapFrame,
                  snapPulse: state._snapPulse,
                  overlays: _LaneOverlays(
                    links: state.widget.links,
                    markers: state.widget.markers,
                    selectedDiamondId: state.widget.selection.selectedDiamondId,
                    selectedLinkId: state.widget.selection.selectedLinkId,
                    hoverBarId: state._hoverBarId,
                    linkDragBarId: state._linkDrag?.bar.id,
                    linkDragPoint: state._linkDrag?.point,
                  ),
                  background: colors.background,
                  rowLine: colors.borderSubtle,
                  detail: colors.text,
                  playheadColor: colors.accent.base,
                  selectionFill: colors.accent.base.withValues(alpha: 0.12),
                  snapColor: colors.text,
                  violationColor: colors.error.base,
                  endShade: colors.overlay.withValues(alpha: 0.25),
                  badgeStyle: labelStyle.copyWith(color: colors.text),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
