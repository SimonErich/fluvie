part of 'spec_validation.dart';

/// One element's `animate` entries: each known preset's arguments are a closed
/// set (the reserved timing-tail keys are always allowed), the multi-stop
/// `keyframes` form is closed over [knownKeyframesFormKeys] plus the tail, and
/// a `particles` entry's nested `spec` is a closed shape too. A raw keyframe
/// entry (no `preset`, no `keyframes`) and an unknown preset are left to the
/// parser, which reports their structural errors. Shader `uniforms` stay
/// deliberately open: every key names one author float slot.
void _checkAnimations(Map<String, Object?> json, List<String> path, List<FluvieSpecWarning> out) {
  final animate = json['animate'];
  if (animate is! List) return;
  for (var i = 0; i < animate.length; i++) {
    final entry = animate[i];
    if (entry is! Map<String, Object?>) continue;
    final preset = entry['preset'];
    if (preset is! String) {
      if (entry.containsKey('keyframes')) {
        _checkKeyframesEntry(entry, [...path, 'animate', '$i'], out);
      }
      continue; // Raw keyframes: the keyframe codec owns them.
    }
    final args = knownAnimationPresetArgs[preset];
    if (args == null) continue; // Unknown preset: the parser reports it.
    final entryPath = [...path, 'animate', '$i'];
    final allowed = {...AnimationSpec.reservedAnimationKeys, ...args};
    for (final key in entry.keys) {
      if (allowed.contains(key)) continue;
      final named = allowed.difference(const {'preset'});
      out.add(
        FluvieSpecWarning(_message(key, 'a $preset animation', named, null), path: entryPath),
      );
    }
    if (preset == 'particles') {
      _checkNested(entry, 'spec', knownParticlesKeys, 'a particles spec', entryPath, out);
    }
  }
}

/// A `keyframes` entry is closed over its own keys plus the timing tail (the
/// stop positions are `positions`; `at` stays the start trigger).
void _checkKeyframesEntry(
  Map<String, Object?> entry,
  List<String> entryPath,
  List<FluvieSpecWarning> out,
) {
  final allowed = {
    ...AnimationSpec.reservedAnimationKeys.difference(const {'preset'}),
    ...knownKeyframesFormKeys,
  };
  for (final key in entry.keys) {
    if (allowed.contains(key)) continue;
    out.add(
      FluvieSpecWarning(_message(key, 'a keyframes animation', allowed, null), path: entryPath),
    );
  }
}
