part of 'command_registry.dart';

/// The timeline's transport and marking commands.
///
/// These are the verbs that act on **time** rather than on the document: they
/// move the playhead and set the marks a later edit will use. None of them
/// dispatches a document command, so none of them is undoable — moving the
/// playhead is not an edit, and putting it on the undo stack would bury the
/// author's real steps under navigation.
///
/// They read the scope's transport fields, which default inert, so a surface
/// with no timeline shows every one of them disabled rather than acting on a
/// playhead it does not have.
final List<EditorCommandEntry> _timelineCommands = [
  ..._timelineTransportCommands,
  ..._timelineEditCommands,
  ..._timelineStructureCommands,
];

/// The selected bars a razor at the playhead would actually cut, in a stable
/// order.
///
/// Cutting the ones it can beats refusing the lot: the author asked for a cut
/// here, and the selected bars that do not reach the playhead are not in the
/// way of the ones that do. An empty answer is what makes the verb read as
/// disabled rather than firing into nothing.
List<String> razorableBars(CommandScope scope) {
  if (!scope.canSeek || scope.timelineSelection.isEmpty) return const [];
  final model = VideoLaneModel.build(document: scope.document);
  return [
    for (final barId in scope.timelineSelection.toList()..sort())
      if (videoBarRazored(model, barId, scope.playhead, document: scope.document)?.command != null)
        barId,
  ];
}

/// Whether the scope has a transport to act on at all.
///
/// A surface that cannot seek has no playhead to mark, and marking one would
/// write a position nothing can reach.
bool _hasTransport(CommandScope scope) => scope.canSeek;

/// Every frame the timeline calls an edit: where each scene begins and ends,
/// and where each one settles after its incoming transition.
///
/// Read from the one timebase the compositor mounts against rather than
/// re-derived, so Next edit can never land somewhere the picture does not
/// actually change. Sorted and deduplicated, because a scene boundary and the
/// settle frame of a cut are one place to land, not two — an author pressing
/// the key twice there would otherwise appear not to move.
List<int> editPoints(CommandScope scope) {
  final timebase = VideoTimebase.of(scope.document);
  final points = <int>{0, timebase.totalFrames};
  for (var scene = 0; scene < timebase.sceneSpans.length; scene++) {
    final span = timebase.sceneSpans[scene];
    points
      ..add(span.start)
      ..add(span.end)
      ..add(timebase.settleFrameOf(scene));
  }
  return points.toList()..sort();
}

/// The first edit point after the playhead, or null when it is already at or
/// past the last one.
int? nextEditPoint(CommandScope scope) {
  for (final point in editPoints(scope)) {
    if (point > scope.playhead) return point;
  }
  return null;
}

/// The last edit point before the playhead, or null when it is at or before
/// the first one.
int? previousEditPoint(CommandScope scope) {
  int? found;
  for (final point in editPoints(scope)) {
    if (point < scope.playhead) {
      found = point;
    } else {
      break;
    }
  }
  return found;
}

List<String> _razorAll(CommandScope scope) {
  final model = VideoLaneModel.build(document: scope.document);
  return [
    for (final id in {...model.elementBars.keys, ...model.overlayBars.keys})
      if (videoBarRazored(model, id, scope.playhead, document: scope.document)?.command != null) id,
  ];
}

EditorCommand? _liftCommand(CommandScope scope) {
  final model = VideoLaneModel.build(document: scope.document);
  final span = scope.markedSpan;
  return span == null
      ? videoLifted(model, scope.timelineSelection, document: scope.document)?.command
      : videoRangeRemoved(
          model,
          span.start,
          span.end,
          document: scope.document,
          bars: _rangeBars(scope, model),
        )?.command;
}

EditorCommand? _extractCommand(CommandScope scope) {
  final span = scope.markedSpan;
  if (span == null) return null;
  final model = VideoLaneModel.build(document: scope.document);
  return videoRangeRemoved(
    model,
    span.start,
    span.end,
    document: scope.document,
    bars: _rangeBars(scope, model),
    ripple: true,
  )?.command;
}

Set<String> _rangeBars(CommandScope scope, VideoLaneModel model) {
  if (scope.timelineSelection.isNotEmpty) return scope.timelineSelection;
  final lane = scope.activeLane;
  if (lane == null) return {...model.elementBars.keys, ...model.overlayBars.keys};
  return {
    for (final row in model.tracks)
      if (row.id == laneRowId(lane)) ...row.bars.map((bar) => bar.id),
  };
}
