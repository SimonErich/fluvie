part of 'video_mode_panel.dart';

extension _VideoModeTracks on _VideoModePanelState {
  String _numberedLabel(TimelineTrack row) {
    final id = laneIdOfRow(row.id);
    if (id == null) return row.label;
    final lane = widget.document.spec.lanes.firstWhere((lane) => lane.id == id);
    final peers = widget.document.spec.lanes
        .where((candidate) => candidate.kind == lane.kind)
        .toList();
    return '${lane.kind.name == 'audio' ? 'A' : 'V'}${peers.indexOf(lane) + 1} · ${row.label}';
  }

  List<TimelineTrack> _decoratedTracks(VideoLaneModel model) {
    final tracks = _fullTracks(model);
    if (!_quick) return tracks;
    return [
      TimelineTrack(
        id: 'quick:pictures',
        label: 'Picture',
        showLaneControls: false,
        bars: [
          for (final row in tracks)
            for (final bar in row.bars)
              if (model.elementBars.containsKey(bar.id) || model.overlayBars.containsKey(bar.id))
                bar,
        ],
      ),
      TimelineTrack(
        id: 'quick:audio',
        label: 'Audio',
        showLaneControls: false,
        bars: [
          for (final row in tracks)
            for (final bar in row.bars)
              if (model.audioBars.containsKey(bar.id)) bar,
        ],
      ),
    ];
  }

  List<TimelineTrack> _fullTracks(VideoLaneModel model) => [
    for (final row in model.tracks)
      TimelineTrack(
        id: row.id,
        label: _numberedLabel(row),
        depth: row.depth,
        isGroup: row.isGroup,
        height: row.height,
        locked: row.locked,
        muted: row.muted,
        showLaneControls: laneIdOfRow(row.id) != null,
        soloed: widget.audioMonitor?.isSoloed(laneIdOfRow(row.id) ?? row.id) ?? false,
        envelope: widget.laneEnvelopes[row.id] ?? row.envelope,
        bars: [
          for (final bar in row.bars)
            TimelineBar(
              id: bar.id,
              start: bar.start,
              end: bar.end,
              color: bar.color,
              easing: bar.easing,
              badge: bar.badge,
              diamonds: bar.diamonds,
              violation: bar.violation,
              thumbnails: widget.thumbnailsByBar[bar.id] ?? bar.thumbnails,
            ),
        ],
      ),
  ];
}
