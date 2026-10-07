import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/serialization/animation_spec.dart';
import 'package:fluvie/src/serialization/audio_track_spec.dart';
import 'package:fluvie/src/serialization/background_spec.dart';
import 'package:fluvie/src/serialization/codecs/box_decoration_codec.dart';
import 'package:fluvie/src/serialization/codecs/geometry_codec.dart';
import 'package:fluvie/src/serialization/codecs/particles_codec.dart';
import 'package:fluvie/src/serialization/codecs/placement_codec.dart';
import 'package:fluvie/src/serialization/effect_spec.dart';
import 'package:fluvie/src/serialization/element_spec.dart';
import 'package:fluvie/src/serialization/lane_spec.dart';
import 'package:fluvie/src/serialization/master_spec.dart';
import 'package:fluvie/src/serialization/scene_spec.dart';
import 'package:fluvie/src/serialization/theme_spec.dart';
import 'package:fluvie/src/serialization/video_spec.dart';

part 'spec_validation_animations.dart';
part 'spec_validation_audio.dart';
part 'spec_validation_elements.dart';
part 'spec_validation_element_nested.dart';
part 'spec_validation_masters.dart';
part 'spec_validation_message.dart';
part 'spec_validation_steps.dart';

/// A non-fatal spec diagnostic: a property Fluvie does not recognize and would
/// silently ignore while rendering.
///
/// Surfaced (not thrown) on the default render path so a typo is visible without
/// failing the render, and promoted to a [FluvieSpecError] on the AI authoring
/// path via [assertNoUnknownSpecProps] so the repair loop corrects it.
final class FluvieSpecWarning {
  /// Creates a warning described by [message], optionally located at [path].
  FluvieSpecWarning(this.message, {this.path = const []});

  /// What was dropped and what was expected, in one actionable sentence.
  final String message;

  /// The chain of JSON keys/indices from the document root to the node carrying
  /// the offending property. Empty when no location applies.
  final List<String> path;

  @override
  String toString() => path.isEmpty ? message : '$message (at ${path.join('.')})';
}

/// Reports every property in [json] (a decoded `VideoSpec` document) that Fluvie
/// does not recognize and would silently drop, each located by its path and
/// naming the allowed keys (with a "did you mean" hint when one is close).
///
/// Pure and side-effect free. It inspects key *names* only, never types or
/// structure ([VideoSpec.fromJson] is the authoritative validator for those), so
/// it is safe on untrusted, partly-malformed input: any node whose shape does
/// not match is skipped and left for the parser to report. Returns an empty list
/// for a clean document.
List<FluvieSpecWarning> unknownSpecProps(Map<String, Object?> json) {
  final warnings = <FluvieSpecWarning>[];
  _checkKeys(json, VideoSpec.knownKeys, 'the video', const [], warnings);
  // The `editor` block is tool-owned and deliberately open; nothing inside
  // it is Fluvie's to second-guess (and the digest ignores it anyway).
  final theme = json['theme'];
  if (theme is Map<String, Object?>) _checkTheme(theme, warnings);
  final masters = json['masters'];
  if (masters is Map<String, Object?>) _checkMasters(masters, warnings);
  _checkAudioTracks(json['audio'], const ['audio'], warnings);
  _checkLanes(json['lanes'], warnings);
  _checkOverlays(json['overlays'], warnings);
  final scenes = json['scenes'];
  if (scenes is! List) return warnings;
  for (var i = 0; i < scenes.length; i++) {
    final scene = scenes[i];
    if (scene is! Map<String, Object?>) continue;
    final scenePath = ['scenes', '$i'];
    _checkKeys(scene, SceneSpec.knownKeys, 'a scene', scenePath, warnings);
    _checkStepsAndNotes(scene, scenePath, warnings);
    _checkSceneMaster(scene, masters, scenePath, warnings);
    _checkAudioTracks(scene['audio'], [...scenePath, 'audio'], warnings);
    final background = scene['background'];
    if (background is Map<String, Object?>) {
      _checkBackground(background, [...scenePath, 'background'], warnings);
    }
    final children = scene['children'];
    if (children is! List) continue;
    for (var j = 0; j < children.length; j++) {
      final child = children[j];
      if (child is! Map<String, Object?>) continue;
      _checkElement(child, [...scenePath, 'children', '$j'], warnings);
    }
  }
  return warnings;
}

/// Reports every unknown property on an overlay, exactly as on a scene child:
/// an overlay is an element, and the same rules read it.
void _checkOverlays(Object? raw, List<FluvieSpecWarning> warnings) {
  if (raw is! List) return;
  for (var i = 0; i < raw.length; i++) {
    final overlay = raw[i];
    if (overlay is! Map<String, Object?>) continue;
    _checkElement(overlay, ['overlays', '$i'], warnings);
  }
}

/// Reports every unknown key on a lane declaration.
void _checkLanes(Object? raw, List<FluvieSpecWarning> warnings) {
  if (raw is! List) return;
  for (var i = 0; i < raw.length; i++) {
    final lane = raw[i];
    if (lane is! Map<String, Object?>) continue;
    _checkKeys(lane, LaneSpec.knownKeys, 'a lane', ['lanes', '$i'], warnings);
  }
}

/// Throws a [FluvieSpecError] enumerating every unknown property in [json], or
/// returns normally when there are none.
///
/// Use on the AI authoring path: a single error lists every stray field at once
/// so the validate-then-repair loop corrects them all in one round instead of
/// rendering a spec whose extra fields are dropped.
void assertNoUnknownSpecProps(Map<String, Object?> json) {
  final unknown = unknownSpecProps(json);
  if (unknown.isEmpty) return;
  final detail = unknown.map((warning) => warning.toString()).join('; ');
  final noun = unknown.length == 1 ? 'property' : 'properties';
  throw FluvieSpecError(
    'The spec has ${unknown.length} $noun Fluvie does not recognize and would ignore: $detail',
  );
}

void _checkNested(
  Map<String, Object?> json,
  String key,
  Set<String> allowed,
  String subject,
  List<String> path,
  List<FluvieSpecWarning> out,
) {
  final nested = json[key];
  if (nested is! Map<String, Object?>) return; // Wrong type: the codec reports it.
  final nestedPath = [...path, key];
  for (final prop in nested.keys) {
    if (allowed.contains(prop)) continue;
    out.add(FluvieSpecWarning(_message(prop, subject, allowed, null), path: nestedPath));
  }
}

/// The theme block: closed over [ThemeSpec.knownKeys], and every type-scale
/// entry a closed *literal* style shape (no `token` — a type-scale style
/// cannot reference tokens, so the parser rejects one anyway).
void _checkTheme(Map<String, Object?> theme, List<FluvieSpecWarning> out) {
  const path = ['theme'];
  _checkKeys(theme, ThemeSpec.knownKeys, 'a theme', path, out);
  final typeScale = theme['typeScale'];
  if (typeScale is! Map<String, Object?>) return; // Wrong type: the parser reports it.
  for (final entry in typeScale.entries) {
    final style = entry.value;
    if (style is! Map<String, Object?>) continue;
    _checkKeys(style, _styleFields, 'a type scale style', [...path, 'typeScale', entry.key], out);
  }
}

void _checkBackground(Map<String, Object?> json, List<String> path, List<FluvieSpecWarning> out) {
  final kind = json['kind'];
  if (kind is! String) return; // Absent/non-string kind: the parser reports it.
  final allowedProps = knownBackgroundProps[kind];
  if (allowedProps == null) return; // Unknown kind: the parser reports it.
  final allowed = {'kind', ...allowedProps};
  for (final key in json.keys) {
    if (allowed.contains(key)) continue;
    out.add(FluvieSpecWarning(_message(key, 'a $kind background', allowedProps, null), path: path));
  }
}

void _checkKeys(
  Map<String, Object?> json,
  Set<String> allowed,
  String subject,
  List<String> path,
  List<FluvieSpecWarning> out,
) {
  for (final key in json.keys) {
    if (allowed.contains(key)) continue;
    out.add(FluvieSpecWarning(_message(key, subject, allowed, null), path: path));
  }
}
