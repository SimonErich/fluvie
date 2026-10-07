part of 'theme_panel.dart';

/// The typography, spacing, and motion sections of the [ThemePanel].
extension _ThemePanelScales on ThemePanel {
  List<Widget> _typeScaleSection(BuildContext context) => [
    for (final entry in _tokenMap('typeScale').entries)
      Padding(
        key: ValueKey('scale-${entry.key}'),
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            OiLabel.small(entry.key, color: context.colors.text),
            OiPropertyGrid(
              properties: [
                OiPropertyRow(
                  label: 'Size',
                  editor: Semantics(
                    container: true,
                    label: '${entry.key} size',
                    child: MathNumberInput(
                      label: '',
                      value: _styleNumber(entry.value, 'fontSize', 24),
                      min: 1,
                      onChanged: (next) => _setStyleField(entry.key, 'fontSize', next),
                    ),
                  ),
                ),
                OiPropertyRow(
                  label: 'Weight',
                  editor: OiSelect<String>(
                    key: ValueKey('theme-weight-${entry.key}'),
                    value: _styleString(entry.value, 'fontWeight') ?? 'w400',
                    options: [
                      for (var w = 100; w <= 900; w += 100)
                        OiSelectOption(value: 'w$w', label: 'w$w'),
                    ],
                    onChanged: (next) {
                      if (next != null) _setStyleField(entry.key, 'fontWeight', next);
                    },
                  ),
                ),
                OiPropertyRow(
                  label: 'Family',
                  editor: Semantics(
                    container: true,
                    label: '${entry.key} family',
                    child: InspectorTextField(
                      value: _styleString(entry.value, 'fontFamily') ?? '',
                      onChanged: (next) =>
                          _setStyleField(entry.key, 'fontFamily', next.isEmpty ? null : next),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
  ];

  Widget _spacingSection(BuildContext context) => OiPropertyGrid(
    properties: [
      for (final entry in _tokenMap('spacing').entries)
        OiPropertyRow(
          label: entry.key,
          editor: Semantics(
            container: true,
            label: '${entry.key} spacing',
            child: MathNumberInput(
              label: '',
              value: entry.value is num ? (entry.value! as num).toDouble() : 0,
              min: 0,
              onChanged: (next) => _set(
                _with('spacing', entry.key, next),
                mergeGroup: 'spacing-${entry.key}',
              ),
            ),
          ),
        ),
    ],
  );

  Widget _motionSection(BuildContext context) {
    final motion = _tokenMap('motion');
    final ease = motion['ease'];
    return OiPropertyGrid(
      properties: [
        OiPropertyRow(
          label: 'Duration',
          editor: Semantics(
            container: true,
            label: 'Motion duration',
            child: InspectorTextField(
              value: motion['duration'] as String? ?? '',
              onChanged: _setMotionDuration,
            ),
          ),
        ),
        OiPropertyRow(
          label: 'Ease',
          editor: OiSelect<String>(
            key: const ValueKey('theme-motion-ease'),
            value: ease is String ? ease : 'none',
            options: [
              const OiSelectOption(value: 'none', label: 'none'),
              for (final name in namedEases.keys) OiSelectOption(value: name, label: name),
            ],
            onChanged: (next) {
              if (next != null) _set(_with('motion', 'ease', next == 'none' ? null : next));
            },
          ),
        ),
      ],
    );
  }

  double _styleNumber(Object? style, String field, double fallback) {
    final value = style is Map ? style[field] : null;
    return value is num ? value.toDouble() : fallback;
  }

  String? _styleString(Object? style, String field) {
    final value = style is Map ? style[field] : null;
    return value is String ? value : null;
  }

  void _setStyleField(String name, String field, Object? value) {
    final style = _tokenMap('typeScale')[name];
    final entry = {if (style is Map<String, Object?>) ...style};
    if (value == null) {
      entry.remove(field);
    } else {
      entry[field] = value;
    }
    _set(_with('typeScale', name, entry), mergeGroup: 'scale-$name-$field');
  }

  /// An empty duration clears it; anything else must parse as a spec time
  /// (`300ms`, `0.5s`, `12f`) or the edit is dropped.
  void _setMotionDuration(String next) {
    if (next.isEmpty) {
      _set(_with('motion', 'duration', null));
      return;
    }
    try {
      decodeTime(next);
    } on Object {
      return;
    }
    _set(_with('motion', 'duration', next));
  }
}
