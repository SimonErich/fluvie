part of 'audio_workspace_panel.dart';

final class _AudioLaneControls extends StatelessWidget {
  const _AudioLaneControls({
    required this.lane,
    required this.meter,
    required this.soloed,
    required this.onGainChanged,
    required this.onMute,
    required this.onSolo,
  });

  final LaneSpec lane;
  final Widget meter;
  final bool soloed;
  final ValueChanged<double> onGainChanged;
  final VoidCallback onMute;
  final VoidCallback onSolo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OiLabel.bodyStrong(lane.name ?? lane.id),
        meter,
        MathNumberInput(
          label: 'Gain dB',
          value: gainToDecibels(lane.gain).clamp(-60, 24),
          min: -60,
          max: 24,
          step: 0.5,
          onChanged: onGainChanged,
        ),
        Wrap(
          spacing: 8,
          children: [
            OiButton.ghost(label: lane.muted ? 'Unmute' : 'Mute', onTap: onMute),
            OiButton.ghost(
              label: soloed ? 'Unsolo monitor' : 'Solo monitor',
              onTap: onSolo,
            ),
          ],
        ),
      ],
    ),
  );
}

final class _DuckingLanePicker extends StatelessWidget {
  const _DuckingLanePicker({
    required this.label,
    required this.value,
    required this.lanes,
    required this.onChanged,
    this.excludedLane,
  });

  final String label;
  final String? value;
  final List<LaneSpec> lanes;
  final ValueChanged<String?> onChanged;
  final String? excludedLane;

  @override
  Widget build(BuildContext context) => OiSelect<String>(
    label: label,
    value: value,
    options: [
      for (final lane in lanes)
        if (lane.id != excludedLane) OiSelectOption(value: lane.id, label: lane.name ?? lane.id),
    ],
    onChanged: onChanged,
  );
}

final class _DuckingTimeInput extends StatelessWidget {
  const _DuckingTimeInput({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => MathNumberInput(
    label: label,
    value: value,
    min: 0,
    max: 10,
    step: 0.05,
    decimals: 2,
    onChanged: onChanged,
  );
}
