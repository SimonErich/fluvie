part of 'effects_section.dart';

extension _EffectsSectionFields on EffectsSection {
  OiPropertyRow _numberRow(int index, EffectSpec spec, EffectParam param) {
    final keyframed = spec.isKeyframed(param.name);
    return OiPropertyRow(
      label: param.name,
      editor: Row(
        children: [
          Expanded(
            child: keyframed
                ? OiLabel.small(
                    '${spec.keyframed(param.name)!.values.length} stops',
                    key: ValueKey('effect-stops-$index-${param.name}'),
                  )
                : MathNumberInput(
                    key: ValueKey('effect-param-$index-${param.name}'),
                    label: '',
                    value: spec.number(param.name),
                    min: param.min,
                    max: param.max,
                    step: param.max - param.min <= 2 ? 0.05 : 1,
                    decimals: 2,
                    onChanged: (next) => onCommand(
                      SetEffectParamCommand(
                        id: elementId,
                        index: index,
                        param: param.name,
                        value: next,
                      ),
                    ),
                  ),
          ),
          EditorTip(
            message: keyframed ? 'Back to a single value' : 'Keyframe this parameter',
            child: OiIconButton(
              key: ValueKey('effect-stopwatch-$index-${param.name}'),
              icon: OiIcons.diamond,
              semanticLabel: keyframed ? 'Stop keyframing ${param.name}' : 'Keyframe ${param.name}',
              size: OiButtonSize.small,
              onTap: () => _toggleStopwatch(index, spec, param, keyframed: keyframed),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleStopwatch(int index, EffectSpec spec, EffectParam param, {required bool keyframed}) {
    final Object? value;
    if (keyframed) {
      // Clamped to the parameter's range: an overshooting easing reads past
      // it mid-segment, and the written literal faces the same range check a
      // typed one would.
      value = stopwatchLiteralFor(
        document,
        elementId,
        spec.keyframed(param.name)!.toJson(),
        progress: playheadProgress?.call(elementId),
      ).clamp(param.min, param.max);
    } else {
      value = stopwatchRampFor(document, elementId, spec.number(param.name));
    }
    onCommand(SetEffectParamCommand(id: elementId, index: index, param: param.name, value: value));
  }

  OiPropertyRow _flagRow(int index, EffectSpec spec, String flag) => OiPropertyRow(
    label: flag,
    editor: OiSwitch(
      key: ValueKey('effect-flag-$index-$flag'),
      value: spec.flag(flag),
      onChanged: (next) => onCommand(
        SetEffectParamCommand(id: elementId, index: index, param: flag, value: next ? true : null),
      ),
    ),
  );

  OiPropertyRow _enumRow(int index, EffectSpec spec, MapEntry<String, List<String>> entry) =>
      OiPropertyRow(
        label: entry.key,
        editor: OiSelect<String>(
          key: ValueKey('effect-enum-$index-${entry.key}'),
          options: [for (final choice in entry.value) OiSelectOption(value: choice, label: choice)],
          value: spec.text(entry.key) ?? entry.value.first,
          onChanged: (next) => onCommand(
            SetEffectParamCommand(id: elementId, index: index, param: entry.key, value: next),
          ),
        ),
      );

  OiPropertyRow _textRow(int index, EffectSpec spec, String name) => OiPropertyRow(
    label: name,
    editor: EffectTextEditor(
      key: ValueKey('effect-text-$index-$name'),
      spec: spec,
      name: name,
      onChanged: (value) =>
          onCommand(SetEffectParamCommand(id: elementId, index: index, param: name, value: value)),
    ),
  );
}
