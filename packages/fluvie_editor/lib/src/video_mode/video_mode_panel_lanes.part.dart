part of 'video_mode_panel.dart';

extension _VideoModeLanes on _VideoModePanelState {
  void _toggleLane(String rowId, String key) {
    final id = laneIdOfRow(rowId);
    if (id == null) return;
    final lane = widget.document.spec.lanes.where((lane) => lane.id == id).firstOrNull;
    if (lane == null) return;
    final value = key == 'locked' ? lane.locked : lane.muted;
    widget.onCommand(SetLaneCommand(id: id, patch: {key: !value}));
  }

  void _reorderLane(VideoLaneModel model, String rowId, int targetRow) {
    final id = laneIdOfRow(rowId);
    if (id == null) return;
    final target = targetRow.clamp(0, model.tracks.length - 1);
    final declaredBefore = model.tracks
        .take(target + 1)
        .where((row) => laneIdOfRow(row.id) != null)
        .length;
    final to = (declaredBefore - 1).clamp(0, widget.document.spec.lanes.length - 1);
    widget.onCommand(ReorderLaneCommand(id: id, to: to));
  }

  bool get _quick => WorkspaceScope.of(context) == EditorWorkspace.quick;

  String _sourceRow(VideoLaneModel model, String row, {required bool audio}) {
    if (!row.startsWith('quick:')) return row;
    final compatible = widget.document.spec.lanes.where(
      (lane) => (lane.kind.name == 'audio') == audio && !lane.locked,
    );
    final active = ref.read(activeTimelineLaneProvider);
    final lane =
        compatible.where((lane) => lane.id == active).firstOrNull ?? compatible.firstOrNull;
    return lane == null ? (audio ? 'quick:audio' : 'quick:pictures') : 'lane:${lane.id}';
  }
}
