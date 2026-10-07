part of 'video_lane_model.dart';

extension _VideoLaneStructure on _VideoLaneBuilder {
  void _transitionLanes() {
    for (var scene = 0; scene < document.sceneCount; scene++) {
      final transitions = document.spec.scenes[scene].transitions;
      for (var i = 0; i < transitions.length; i++) {
        final edge = transitions[i];
        final incoming = introspection.scenes[scene].elementById(edge.incoming);
        if (incoming == null) continue;
        final frames = edge.transition.duration.resolveFrames(
          OwnerFrameScope(timebase.fps, timebase.sceneSpans[scene]),
        );
        final window = FrameSpan(incoming.window.start, incoming.window.start + frames);
        final lane = document.elementJson(edge.incoming)?['lane'];
        final locked = document.spec.lanes.any((item) => item.id == lane && item.locked);
        final id = 'transition:$scene:$i';
        transitionBars[id] = VideoTransitionBinding(
          scene: scene,
          index: i,
          spec: edge,
          window: window,
          locked: locked,
        );
        tracks.add(
          TimelineTrack(
            id: 'transition-track:$scene:$i',
            label: '${edge.outgoing} → ${edge.incoming}',
            depth: 1,
            locked: locked,
            bars: [
              TimelineBar(
                id: id,
                start: window.start.toDouble(),
                end: window.end.toDouble(),
                color: palette.sfx,
                badge: edge.transition.customKind ?? edge.transition.kind.name,
              ),
            ],
          ),
        );
      }
    }
  }

  /// One row per lane the document declares, in declaration order, before any
  /// material lands on it.
  ///
  /// A declared lane with nothing on it is still a row: it is where the author
  /// drags the next clip, and a row that appeared only once something was on
  /// it would be a row nobody could aim at.
  void _declaredLanes() {
    for (final lane in document.spec.lanes) {
      tracks.add(
        TimelineTrack(
          id: laneRowId(lane.id),
          label: lane.name ?? lane.id,
          height: lane.height,
          locked: lane.locked,
          muted: lane.muted,
        ),
      );
    }
  }

  /// Puts [bar] on the row for [laneId], or on a row of its own named
  /// [ownRowId] when the bar names no lane (or names one the document does
  /// not declare — the parser refuses that, so it can only be a stale model).
  void _place({
    required String? laneId,
    required String ownRowId,
    required String label,
    required TimelineBar bar,
  }) {
    final row = laneId == null ? -1 : tracks.indexWhere((t) => t.id == laneRowId(laneId));
    if (row >= 0) {
      tracks[row] = tracks[row].withBars([...tracks[row].bars, bar]);
      return;
    }
    tracks.add(TimelineTrack(id: ownRowId, label: label, bars: [bar]));
  }

  void _scenesLane() {
    tracks.add(
      TimelineTrack(
        id: 'scenes',
        label: 'Scenes',
        bars: [
          for (var i = 0; i < timebase.sceneSpans.length; i++)
            TimelineBar(
              id: 'scene:$i',
              start: timebase.sceneSpans[i].start.toDouble(),
              end: timebase.sceneSpans[i].end.toDouble(),
              color: palette.scene,
              badge: 'Slide ${i + 1}',
            ),
        ],
      ),
    );
    for (var i = 1; i < timebase.sceneSpans.length; i++) {
      markers.add(
        TimelineMarker(id: 'boundary:$i', frame: timebase.sceneSpans[i].start.toDouble()),
      );
    }
  }

  /// The element ids scene [scene]'s build `steps` claim — what a
  /// cross-scene move must strip and honestly note.
  Set<String> _stepIdsOf(int scene) {
    final steps = document.sceneJson(scene)['steps'];
    if (steps is! List) return const {};
    return {
      for (final step in steps.whereType<Map<String, Object?>>())
        if (step['elements'] case final List<Object?> elements) ...elements.whereType<String>(),
    };
  }
}
