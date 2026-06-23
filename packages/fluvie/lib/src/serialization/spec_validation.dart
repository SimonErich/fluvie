import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/serialization/background_spec.dart';
import 'package:fluvie/src/serialization/element_spec.dart';
import 'package:fluvie/src/serialization/scene_spec.dart';
import 'package:fluvie/src/serialization/video_spec.dart';

part 'spec_validation_message.dart';

/// A non-fatal spec diagnostic: a property Fluvie does not recognize and would
/// silently ignore while rendering.
///
/// Surfaced (not thrown) on the default render path so a typo is visible without
/// failing the render, and promoted to a [FluvieSpecError] on the AI authoring
/// path via [assertNoUnknownSpecProps] so the repair loop corrects it.
class FluvieSpecWarning {
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

/// The element keys [ElementSpec.fromJson] reserves; mirror of its private set.
const Set<String> _reservedElementKeys = {'type', 'anchor', 'animate'};

/// Text-style fields (the `decodeTextStyle` subset): the contents of a `"style"`
/// object, also used to hint when one is mistakenly placed at the top level of a
/// `Text`/`Counter`.
const Set<String> _styleFields = {
  'color',
  'fontSize',
  'fontWeight',
  'fontFamily',
  'letterSpacing',
  'height',
};

/// The closed nested object shapes, mirrored from the codecs: a `Box` `size`
/// ({width, height}) and an `Image` `source` ({kind, value}).
const Set<String> _sizeFields = {'width', 'height'};
const Set<String> _sourceFields = {'kind', 'value'};

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
  final scenes = json['scenes'];
  if (scenes is! List) return warnings;
  for (var i = 0; i < scenes.length; i++) {
    final scene = scenes[i];
    if (scene is! Map<String, Object?>) continue;
    final scenePath = ['scenes', '$i'];
    _checkKeys(scene, SceneSpec.knownKeys, 'a scene', scenePath, warnings);
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

void _checkElement(Map<String, Object?> json, List<String> path, List<FluvieSpecWarning> out) {
  final type = json['type'];
  if (type is! String) return; // Absent/non-string type: the parser reports it.
  final allowedProps = knownElementProps[type];
  if (allowedProps == null) return; // Unknown type: the parser reports it.
  final allowed = {..._reservedElementKeys, ...allowedProps};
  for (final key in json.keys) {
    if (allowed.contains(key)) continue;
    out.add(FluvieSpecWarning(_message(key, 'a $type', allowedProps, type), path: path));
  }
  // The curated nested objects are closed shapes too: a typo inside style/size/
  // source is dropped by the codec, so check one level deeper.
  if (type == 'Text' || type == 'Counter') {
    _checkNested(json, 'style', _styleFields, 'a text style', path, out);
  } else if (type == 'Box') {
    _checkNested(json, 'size', _sizeFields, 'a Box size', path, out);
  } else if (type == 'Image') {
    _checkNested(json, 'source', _sourceFields, 'an image source', path, out);
  }
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
