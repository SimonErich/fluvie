part of 'track_timeline.dart';

// obers_ui upstream candidate (part of track_timeline.dart): the labels
// column and the empty state.

extension _TrackTimelineLabels on _TrackTimelineState {
  /// The single-line empty state: the message plus the host's action slot —
  /// empty is never a dead end.
  Widget _emptyState(BuildContext context) {
    final action = widget.appearance.emptyAction;
    return ColoredBox(
      color: context.colors.surface,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: OiLabel.small(
                widget.appearance.emptyMessage,
                color: context.colors.textSubtle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (action != null) ...[const SizedBox(width: 12), action],
          ],
        ),
      ),
    );
  }

  /// The label rows, offset by the vertical scroll to stay in step with the
  /// lanes, and built only for the rows the column can actually show.
  ///
  /// Its own [LayoutBuilder] rather than the lanes' measured height: on the
  /// first frame the lanes have not been laid out yet, and a column that
  /// believed it was zero tall would build one label and then flash the rest
  /// in on the next frame.
  Widget _labelsColumn(BuildContext context, List<TimelineTrack> visible) => LayoutBuilder(
    builder: (context, constraints) {
      final band = _rows.visibleRange(_scrollY, constraints.maxHeight);
      if (band == null) return const SizedBox.shrink();
      return Stack(
        children: [
          for (var i = band.first; i <= band.last; i++)
            Positioned(
              left: 0,
              right: 0,
              top: _rows.topOf(i) - _scrollY,
              height: _rows.heightOf(i),
              child: _TrackLabel(
                track: visible[i],
                collapsed: _controller.isCollapsed(visible[i].id),
                selected: widget.selection.selectedTrackIds.contains(visible[i].id),
                onToggle: () => _controller.toggleCollapsed(visible[i].id),
                onTap: widget.navigation.onLabelTapped,
                onLockToggled: widget.lanes.onLaneLockToggled,
                onMuteToggled: widget.lanes.onLaneMuteToggled,
                onSoloToggled: widget.lanes.onLaneSoloToggled,
                onReordered: widget.lanes.onLaneReordered == null
                    ? null
                    : (dy) => _reorderLane(visible, i, dy),
              ),
            ),
        ],
      );
    },
  );

  /// A label dragged [dy] pixels from row [row]: the row it landed on, or
  /// nothing when it did not leave its own band.
  void _reorderLane(List<TimelineTrack> visible, int row, double dy) {
    final target = _rows.clampedRowAt(_rows.topOf(row) + _rows.heightOf(row) / 2 + dy);
    if (target != row) widget.lanes.onLaneReordered?.call(visible[row].id, target);
  }
}

/// One row of the labels column: the indent, a collapse chevron for groups,
/// and the track name. The name is its own tap target for selection, kept
/// apart from the chevron so collapsing never selects.
final class _TrackLabel extends StatefulWidget {
  const _TrackLabel({
    required this.track,
    required this.collapsed,
    required this.selected,
    required this.onToggle,
    required this.onTap,
    required this.onLockToggled,
    required this.onMuteToggled,
    required this.onSoloToggled,
    required this.onReordered,
  });

  final TimelineTrack track;
  final bool collapsed;
  final bool selected;
  final VoidCallback onToggle;
  final ValueChanged<String>? onTap;
  final ValueChanged<String>? onLockToggled;
  final ValueChanged<String>? onMuteToggled;
  final ValueChanged<String>? onSoloToggled;
  final ValueChanged<double>? onReordered;

  @override
  State<_TrackLabel> createState() => _TrackLabelState();
}

final class _TrackLabelState extends State<_TrackLabel> {
  /// How far this label has been dragged in the current gesture. A reorder is
  /// reported once, on release, so the rows do not shuffle under the pointer.
  double _dragged = 0;

  TimelineTrack get track => widget.track;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        SizedBox(width: 8 + track.depth * 12),
        if (track.isGroup)
          GestureDetector(
            key: ValueKey('timeline-collapse-${track.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.onToggle,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: OiIcon.decorative(
                icon: widget.collapsed ? OiIcons.chevronRight : OiIcons.chevronDown,
                size: 12,
                color: colors.textSubtle,
              ),
            ),
          )
        else
          const SizedBox(width: 16),
        const SizedBox(width: 2),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap == null ? null : () => widget.onTap!(track.id),
            onVerticalDragStart: widget.onReordered == null ? null : (_) => _dragged = 0,
            onVerticalDragUpdate: widget.onReordered == null
                ? null
                : (details) => _dragged += details.delta.dy,
            onVerticalDragEnd: widget.onReordered == null
                ? null
                : (_) => widget.onReordered!(_dragged),
            child: OiLabel.tiny(
              track.label,
              color: widget.selected ? colors.accent.base : colors.text,
              maxLines: 1,
            ),
          ),
        ),
        if (track.showLaneControls)
          _toggle(colors, OiIcons.lock, 'Lock', track.locked, widget.onLockToggled),
        if (track.showLaneControls)
          _toggle(colors, OiIcons.volumeX, 'Mute', track.muted, widget.onMuteToggled),
        if (track.showLaneControls)
          _toggle(colors, OiIcons.headphones, 'Solo', track.soloed, widget.onSoloToggled),
      ],
    );
  }

  /// One lane affordance. The widget paints the state and reports the tap;
  /// what a lock forbids or a solo silences is the host's business.
  Widget _toggle(
    OiColorScheme colors,
    IconData icon,
    String name,
    bool on,
    ValueChanged<String>? onToggled,
  ) {
    if (onToggled == null) return const SizedBox.shrink();
    return GestureDetector(
      key: ValueKey('timeline-${name.toLowerCase()}-${track.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onToggled(track.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Semantics(
          label: '$name ${track.label}',
          button: true,
          child: OiIcon.decorative(
            icon: icon,
            size: 11,
            color: on ? colors.accent.base : colors.textSubtle.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
