part of 'video_lane_model.dart';

extension _VideoLaneElements on _VideoLaneBuilder {
  /// One lane per clip or explicitly windowed element; everything else
  /// stays canvas-only (its timing lives in slides mode's animation bars).
  void _elementLane(String id, int scene, {required Set<String> stepIds, bool grouped = false}) {
    final json = document.elementJson(id) ?? const {};
    final hasWindow = json.containsKey('show');
    if (json['type'] != 'Clip' && !hasWindow && json['shared'] == null) return;
    final sceneSpan = timebase.sceneSpans[scene];
    final window = introspection.scenes[scene].elementById(id)?.window ?? sceneSpan;
    final barId = 'el:$id';
    _place(
      laneId: json['lane'] is String ? json['lane']! as String : null,
      ownRowId: 'el-track:$id',
      label: _elementLabel(id, json),
      bar: TimelineBar(
        id: barId,
        start: window.start.toDouble(),
        end: window.end.toDouble(),
        color: palette.element,
        badge: _elementLabel(id, json),
      ),
    );
    elementBars[barId] = VideoElementLaneBinding(
      elementId: id,
      scene: scene,
      sceneSpan: sceneSpan,
      window: window,
      hasWindow: hasWindow,
      inSteps: stepIds.contains(id),
      isGrouped: grouped,
    );
    _effectRows(id, json, window);
  }

  /// Collapses the separately resolved scene windows into one logical bar.
  /// Per-member bindings remain available for editing without losing scene clocks.
  void _collapseSharedChains() {
    final chains = <String, List<VideoElementLaneBinding>>{};
    for (final binding in elementBars.values) {
      final shared = document.elementJson(binding.elementId)?['shared'];
      if (shared is String) (chains[shared] ??= []).add(binding);
    }
    for (final members in chains.values) {
      if (members.length < 2) continue;
      members.sort((a, b) => a.scene.compareTo(b.scene));
      final first = members.first;
      final last = members.last;
      final ids = {for (final member in members) 'el:${member.elementId}'};
      final start = members.map((m) => m.window.start).reduce((a, b) => a < b ? a : b);
      final end = members.map((m) => m.window.end).reduce((a, b) => a > b ? a : b);
      final primary = 'el:${first.elementId}';
      for (var i = tracks.length - 1; i >= 0; i--) {
        final row = tracks[i];
        final bars = <TimelineBar>[];
        for (final bar in row.bars) {
          if (!ids.contains(bar.id)) {
            bars.add(bar);
            continue;
          }
          if (bar.id == primary) {
            bars.add(
              TimelineBar(
                id: primary,
                start: start.toDouble(),
                end: end.toDouble(),
                color: bar.color,
                badge: '${bar.badge} · shared',
              ),
            );
          }
        }
        if (bars.isEmpty &&
            row.id.startsWith('el-track:') &&
            row.bars.any((bar) => ids.contains(bar.id))) {
          tracks.removeAt(i);
        } else {
          tracks[i] = row.withBars(bars);
        }
      }
      elementBars.removeWhere((id, _) => ids.contains(id));
      elementBars[primary] = VideoElementLaneBinding(
        elementId: first.elementId,
        scene: first.scene,
        sceneSpan: FrameSpan(first.sceneSpan.start, last.sceneSpan.end),
        window: FrameSpan(start, end),
        hasWindow: members.any((m) => m.hasWindow),
        isGrouped: members.any((m) => m.isGrouped),
        inSteps: members.any((m) => m.inSteps),
        members: List.unmodifiable(members),
      );
    }
  }

  String _elementLabel(String id, Map<String, Object?> json) {
    final name = document.elementMeta(id)['name'];
    final label = name is String && name.isNotEmpty ? name : json['type'] as String? ?? id;
    if (json['type'] != 'Clip') return label;
    if (json['speed'] is Map) return '$label · speed ramp';
    final speed = json['speed'];
    return speed is num && speed != 1 ? '$label · $speed×' : label;
  }
}
