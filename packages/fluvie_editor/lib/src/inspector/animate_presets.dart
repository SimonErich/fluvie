import 'package:fluvie/fluvie.dart' show knownAnimationPresets;
import 'package:obers_ui/obers_ui.dart' show OiSelectOption;

/// The Animate panel's preset vocabulary: a curated common subset grouped
/// by phase up front, the rest of `knownAnimationPresets` behind a `More`
/// heading — all searchable through the select's filter.

/// The curated groups: the presets a slide author reaches for first, under
/// their phase heading. `keyframes` (the multi-stop form) rides Emphasis.
const Map<String, List<String>> _curatedGroups = {
  'Enter': ['fadeIn', 'slideIn', 'slideFadeIn', 'scaleIn', 'pop', 'blurIn'],
  'Emphasis': ['keyframes', 'float', 'pulse', 'spin', 'drift', 'kenBurns'],
  'Exit': ['fadeOut', 'slideOut', 'slideFadeOut', 'scaleOut', 'blurOut'],
};

/// The sentinel prefix heading options carry; headings are disabled and
/// never selectable, but taps on them still reach `onChanged` in tests.
const String _headingPrefix = '—';

/// Whether [value] is a group heading rather than a preset name.
bool isAnimatePresetHeading(String value) => value.startsWith(_headingPrefix);

/// The add picker's options: curated phase groups first, then every other
/// known preset alphabetically under `More`.
List<OiSelectOption<String>> animatePresetOptions() {
  final listed = {for (final names in _curatedGroups.values) ...names};
  final more = [...knownAnimationPresets.where((preset) => !listed.contains(preset))]..sort();
  return [
    for (final group in _curatedGroups.entries) ...[
      OiSelectOption(value: '$_headingPrefix${group.key}', label: group.key, enabled: false),
      for (final name in group.value) OiSelectOption(value: name, label: name),
    ],
    const OiSelectOption(value: '${_headingPrefix}More', label: 'More', enabled: false),
    for (final name in more) OiSelectOption(value: name, label: name),
  ];
}

/// What an animation row calls one `animate` entry: its label when the
/// author named it, else its preset name, else the self-naming form.
String animationName(Map<String, Object?> json) {
  final label = json['label'];
  if (label is String && label.isNotEmpty) return label;
  final preset = json['preset'];
  if (preset is String) return preset;
  if (json.containsKey('keyframes')) return 'keyframes';
  if (json.containsKey('from') && json.containsKey('to')) return 'fromTo';
  if (json.containsKey('from')) return 'from';
  return 'to';
}
