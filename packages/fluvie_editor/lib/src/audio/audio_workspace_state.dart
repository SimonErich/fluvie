part of 'audio_workspace_panel.dart';

final class _AudioWorkspacePanelState extends State<AudioWorkspacePanel> {
  final _localMonitor = AudioMonitorController();
  String? _trigger;
  String? _target;
  double _attenuation = -12;
  double _attack = 0.1;
  double _hold = 0.2;
  double _release = 0.4;
  AudioMonitorController get _monitor => widget.monitor ?? _localMonitor;
  @override
  void dispose() {
    _localMonitor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _monitor,
    builder: (context, _) {
      final tracks = audioTrackViews(
        widget.document,
        widget.timebase,
        clipMetadata: widget.clipMetadata,
      );
      final lanes = widget.document.spec.lanes
          .where(
            (lane) =>
                lane.kind == LaneKind.audio || tracks.any((track) => track.spec.lane == lane.id),
          )
          .toList();
      final master = AudioMeterLevel.mix(tracks.map(_level));
      final laneIds = lanes.map((lane) => lane.id).toSet();
      final trigger = laneIds.contains(_trigger) ? _trigger : null;
      final target = laneIds.contains(_target) ? _target : null;
      return _AudioWorkspaceView(
        state: this,
        tracks: tracks,
        lanes: lanes,
        master: master,
        trigger: trigger,
        target: target,
        laneControls: [
          for (final lane in lanes)
            _AudioLaneControls(
              lane: lane,
              meter: _meter(
                lane.name ?? lane.id,
                AudioMeterLevel.mix(
                  tracks.where((track) => track.spec.lane == lane.id).map(_level),
                ),
              ),
              soloed: _monitor.isSoloed(lane.id),
              onGainChanged: (db) => widget.onCommand(
                SetLaneCommand(id: lane.id, patch: {'gain': decibelsToGain(db)}),
              ),
              onMute: () => widget.onCommand(
                SetLaneCommand(id: lane.id, patch: {'muted': !lane.muted}),
              ),
              onSolo: () => _monitor.toggleSolo(lane.id),
            ),
        ],
        onApplyDucking:
            trigger == null ||
                target == null ||
                trigger == target ||
                !tracks.any((t) => t.spec.lane == trigger) ||
                !tracks.any((t) => t.spec.lane == target)
            ? null
            : () => _applyDucking(tracks, trigger, target),
      );
    },
  );

  AudioMeterLevel _level(AudioTrackView track) {
    final envelope = widget.envelopes[track.sourceKey];
    return envelope == null
        ? const AudioMeterLevel()
        : meterTrack(
            track: track.resolved,
            envelope: envelope,
            seconds: widget.currentFrame / widget.timebase.fps,
            monitorGain: _monitor.gainForLane(track.spec.lane),
          );
  }

  void _applyDucking(List<AudioTrackView> tracks, String trigger, String target) {
    final presence = tracks
        .where((t) => t.spec.lane == trigger && t.resolved.volume > 0)
        .map((t) => t.span)
        .toList();
    widget.onCommand(
      DuckAudioTracksCommand(
        clipEnvelopes: {
          for (final track in tracks)
            if (track.spec.lane == target && track.elementId != null)
              track.elementId!: duckingAutomation(
                presence: presence,
                target: track.span,
                fps: widget.timebase.fps,
                attenuationDb: _attenuation,
                attackSeconds: _attack,
                holdSeconds: _hold,
                releaseSeconds: _release,
              ),
        },
        envelopes: [
          for (final track in tracks)
            if (track.spec.lane == target && track.elementId == null)
              (
                scene: track.scene,
                index: track.index,
                automation: duckingAutomation(
                  presence: presence,
                  target: track.span,
                  fps: widget.timebase.fps,
                  attenuationDb: _attenuation,
                  attackSeconds: _attack,
                  holdSeconds: _hold,
                  releaseSeconds: _release,
                ),
              ),
        ],
      ),
    );
  }

  void _selectTrigger(String? value) => setState(() => _trigger = value);

  void _selectTarget(String? value) => setState(() => _target = value);

  void _setAttenuation(double v) => setState(() => _attenuation = v);

  void _setAttack(double v) => setState(() => _attack = v);

  void _setHold(double v) => setState(() => _hold = v);

  void _setRelease(double v) => setState(() => _release = v);

  Widget _automation(AudioTrackView track) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OiLabel.body(track.label),
        if (track.unavailableReason != null) OiLabel.small(track.unavailableReason!),
        VolumeAutomationEditor(
          automation: track.spec.automation,
          span: track.span,
          fps: widget.timebase.fps,
          currentFrame: widget.currentFrame,
          onChanged: (value) => widget.onCommand(
            track.elementId != null
                ? DuckAudioTracksCommand(
                    envelopes: const [],
                    clipEnvelopes: {track.elementId!: value ?? const {}},
                    label: 'Edit clip volume automation',
                  )
                : SetAudioTrackCommand(
                    scene: track.scene,
                    index: track.index,
                    patch: {'automation': value},
                  ),
          ),
        ),
      ],
    ),
  );
}
