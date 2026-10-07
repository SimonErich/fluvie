part of 'audio_workspace_panel.dart';

final class _AudioWorkspaceView extends StatelessWidget {
  const _AudioWorkspaceView({
    required this.state,
    required this.tracks,
    required this.lanes,
    required this.master,
    required this.trigger,
    required this.target,
    required this.laneControls,
    required this.onApplyDucking,
  });

  final _AudioWorkspacePanelState state;
  final List<AudioTrackView> tracks;
  final List<LaneSpec> lanes;
  final AudioMeterLevel master;
  final String? trigger;
  final String? target;
  final List<Widget> laneControls;
  final VoidCallback? onApplyDucking;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      const OiLabel.bodyStrong('Audio mix'),
      const SizedBox(height: 8),
      state._meter('Master', master),
      OiLabel.small(
        state.widget.envelopes.isEmpty
            ? 'Import audio to analyze meter levels.'
            : 'Estimated levels from cached audio; peak is a conservative ceiling.',
      ),
      ...laneControls,
      if (lanes.isEmpty)
        const OiLabel.small(
          'Add audio lanes in the timeline to group tracks and apply ducking.',
        ),
      const SizedBox(height: 12),
      const OiLabel.bodyStrong('Ducking'),
      const SizedBox(height: 8),
      _DuckingLanePicker(
        label: 'Trigger lane',
        value: trigger,
        lanes: lanes,
        onChanged: state._selectTrigger,
      ),
      const SizedBox(height: 8),
      _DuckingLanePicker(
        label: 'Target lane',
        value: target,
        lanes: lanes,
        excludedLane: trigger,
        onChanged: state._selectTarget,
      ),
      const SizedBox(height: 8),
      MathNumberInput(
        label: 'Reduction dB',
        value: state._attenuation,
        min: -60,
        max: 0,
        onChanged: state._setAttenuation,
      ),
      _DuckingTimeInput(
        label: 'Attack seconds',
        value: state._attack,
        onChanged: state._setAttack,
      ),
      _DuckingTimeInput(
        label: 'Hold seconds',
        value: state._hold,
        onChanged: state._setHold,
      ),
      _DuckingTimeInput(
        label: 'Release seconds',
        value: state._release,
        onChanged: state._setRelease,
      ),
      OiButton.secondary(label: 'Apply ducking', onTap: onApplyDucking),
      const SizedBox(height: 16),
      const OiLabel.bodyStrong('Volume automation'),
      for (final track in tracks) state._automation(track),
    ],
  );
}
