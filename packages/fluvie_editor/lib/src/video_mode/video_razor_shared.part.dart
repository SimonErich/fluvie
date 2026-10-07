part of 'video_razor.dart';

VideoLaneEdit _sharedRazored(
  VideoLaneModel model,
  VideoElementLaneBinding chain,
  int frame,
  EditorDocument document,
  String? tailId,
  String? mergeGroup,
) {
  if (frame <= chain.window.start || frame >= chain.window.end) {
    return const VideoLaneEdit.refused('Put the playhead inside the shared chain to razor it.');
  }
  final replacements = <String, Map<String, Object?>>{};
  final tails = <String, Map<String, Object?>>{};
  final ids = document.nextIds(chain.members.length + 1).where((id) => id != tailId).toList();
  final desired = tailId ?? ids.removeAt(0);
  var shared = 'split:$desired';
  final sharedNames = {
    for (final member in model.elementBars.values)
      document.elementJson(member.elementId)?['shared'],
  };
  var suffix = 0;
  while (sharedNames.contains(shared)) {
    shared = 'split:$desired:${++suffix}';
  }
  String? primary;
  final timeline = chain.members.any((member) => member.isGrouped)
      ? introspectTimeline(document.spec.build())
      : null;
  for (final member in chain.members) {
    if (member.window.end <= frame) continue;
    final element = document.elementJson(member.elementId)!;
    if (document.spec.lanes.any((lane) => lane.id == element['lane'] && lane.locked)) {
      return const VideoLaneEdit.refused(
        'Unlock every member lane before splitting the shared chain.',
      );
    }
    if (member.window.start >= frame) {
      replacements[member.elementId] = {...element, 'shared': shared};
      primary ??= member.elementId;
      continue;
    }
    final newId = primary == null ? desired : ids.removeAt(0);
    primary ??= newId;
    final origin = timeline == null
        ? member.sceneSpan.start
        : videoElementOwner(document, timeline, member.elementId).start;
    final head = {
      ...element,
      'show': {'from': '${member.window.start - origin}f', 'to': '${frame - origin}f'},
    };
    final tail = {
      ...element,
      'id': newId,
      'shared': shared,
      'show': {'from': '${frame - origin}f', 'to': '${member.window.end - origin}f'},
    }..remove('anchor');
    if (element['type'] == 'Clip') {
      final split = _splitTrim(
        element,
        fps: model.fps,
        elapsed: (frame - member.window.start) / model.fps,
        remaining: (member.window.end - frame) / model.fps,
      );
      if (split is _TrimRefusal) return VideoLaneEdit.refused(split.note);
      head['trim'] = (split as _TrimSplit).headTrim;
      tail['trim'] = split.tailTrim;
      if (split.headSpeed != null) head['speed'] = split.headSpeed;
      if (split.tailSpeed != null) tail['speed'] = split.tailSpeed;
    }
    _splitAudio(
      element,
      head,
      tail,
      frame - member.window.start,
      member.window.durationFrames,
      model.fps,
    );
    replacements[member.elementId] = head;
    tails[member.elementId] = tail;
  }
  if (primary == null) return const VideoLaneEdit.refused('No material follows that cut.');
  return VideoLaneEdit.command(
    SplitSharedChainCommand(
      members: replacements,
      tails: tails,
      tailPrimaryId: primary,
      mergeGroup: mergeGroup,
    ),
  );
}
