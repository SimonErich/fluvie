part of 'clip_speed_section.dart';

final class _ClipSpeedRampEditor extends StatelessWidget {
  const _ClipSpeedRampEditor({
    required this.ramp,
    required this.positions,
    required this.onRamp,
    required this.onConstant,
  });

  final KeyframedNumber ramp;
  final List<double> positions;
  final ValueChanged<KeyframedNumber> onRamp;
  final VoidCallback onConstant;

  void _value(int i, double value) {
    final values = [...ramp.values]..[i] = value;
    onRamp(KeyframedNumber(values: values, positions: ramp.positions, easings: ramp.easings));
  }

  void _position(int i, double value) {
    final changed = [...positions]..[i] = value / 100;
    onRamp(
      KeyframedNumber(
        values: ramp.values,
        positions: changed.map(Time.relative).toList(),
        easings: ramp.easings,
      ),
    );
  }

  void _easing(int i, Object value) {
    final easings = [...ramp.easings]..[i] = decodeCurve(value);
    onRamp(KeyframedNumber(values: ramp.values, positions: ramp.positions, easings: easings));
  }

  void _addMiddle() {
    var segment = 0;
    for (var i = 1; i < positions.length - 1; i++) {
      if (positions[i + 1] - positions[i] > positions[segment + 1] - positions[segment]) {
        segment = i;
      }
    }
    final at = segment + 1;
    final values = [...ramp.values]..insert(at, (ramp.values[segment] + ramp.values[at]) / 2);
    final times = [...positions]..insert(at, (positions[segment] + positions[at]) / 2);
    final easings = [...ramp.easings]..insert(segment, ramp.easings[segment]);
    onRamp(
      KeyframedNumber(
        values: values,
        positions: times.map(Time.relative).toList(),
        easings: easings,
      ),
    );
  }

  void _removeMiddle() {
    final at = ramp.values.length ~/ 2;
    final values = [...ramp.values]..removeAt(at);
    final times = [...ramp.positions]..removeAt(at);
    final easings = [...ramp.easings]..removeAt(at);
    onRamp(KeyframedNumber(values: values, positions: times, easings: easings));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OiLabel.small('Speed ramp · source range preserved', color: context.colors.textSubtle),
        for (var i = 0; i < ramp.values.length; i++) ...[
          MathNumberInput(
            key: ValueKey('speed-stop-$i'),
            label: 'Stop ${i + 1} ×',
            value: ramp.values[i],
            min: 0.01,
            step: 0.05,
            decimals: 3,
            onChanged: (value) => _value(i, value),
          ),
          if (i > 0 && i < ramp.values.length - 1)
            MathNumberInput(
              key: ValueKey('speed-position-$i'),
              label: 'Stop ${i + 1} position %',
              value: positions[i] * 100,
              min: positions[i - 1] * 100 + 0.1,
              max: positions[i + 1] * 100 - 0.1,
              onChanged: (value) => _position(i, value),
            ),
          if (i < ramp.easings.length)
            EasingCurveEditor(
              value: encodeCurve(ramp.easings[i]),
              onChanged: (value) => _easing(i, value),
            ),
        ],
        OiButton.ghost(label: 'Add middle speed stop', onTap: _addMiddle),
        if (ramp.values.length > 2)
          OiButton.ghost(label: 'Remove middle speed stop', onTap: _removeMiddle),
        OiButton.ghost(label: 'Use constant speed', onTap: onConstant),
      ],
    );
  }
}
