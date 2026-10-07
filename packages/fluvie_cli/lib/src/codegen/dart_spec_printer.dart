import 'package:dart_style/dart_style.dart';
import 'package:meta/meta.dart';

part 'dart_spec_printer_anchors.dart';
part 'dart_spec_printer_animations.dart';
part 'dart_spec_printer_annotations.dart';
part 'dart_spec_printer_audio.dart';
part 'dart_spec_printer_backgrounds.dart';
part 'dart_spec_printer_charts.dart';
part 'dart_spec_printer_comments.dart';
part 'dart_spec_printer_effects.dart';
part 'dart_spec_printer_elements.dart';
part 'dart_spec_printer_group.dart';
part 'dart_spec_printer_literals.dart';
part 'dart_spec_printer_masters.dart';
part 'dart_spec_printer_presets_wave2.dart';
part 'dart_spec_printer_styles.dart';
part 'dart_spec_printer_terminal_code.dart';
part 'dart_spec_printer_text.dart';
part 'dart_spec_printer_theme.dart';
part 'dart_spec_printer_timing.dart';
part 'dart_spec_printer_web.dart';
part 'dart_spec_printer_wrappers.dart';

/// Prints a decoded `VideoSpec` JSON document as a Flutter-style Dart snippet:
/// a top-level `Video build()` that returns the same composition the spec
/// builds, ready to drop into the Playground editor and render.
///
/// [spec] is the canonical JSON form (the output of `VideoSpec.toJson`), made of
/// primitives, lists, and maps — no Flutter types — so this stays pure Dart and
/// runs in the render server without the engine. The printed code mirrors the
/// spec's builders (`buildElement`/`buildAnimation`/`buildBackground`) call for
/// call, so rendering the code matches rendering the spec.
///
/// Anchors are declared once as `final` locals and referenced by variable in
/// both the element's `.animate(anchor: ...)` and any `Trigger.whenEnds(...)`,
/// because `Anchor` identity is by reference: two `Anchor('x')` literals would
/// name two distinct timelines.
///
/// All author-supplied strings (text, image URLs, labels) are emitted as
/// escaped single-quoted literals, so a crafted prompt cannot break out of the
/// string or inject code.
///
/// The result is formatted with `dart_style`; malformed output would throw here
/// rather than reach a caller.
@experimental
String printVideoSpecJson(Map<String, Object?> spec) {
  // Printed Dart is the render: adopting scenes resolve their master first
  // (see dart_spec_printer_masters.dart), so anchors and elements print
  // from the fully freeform document.
  final resolution = _applyMasters(spec);
  final resolved = resolution.spec;
  final anchors = _Anchors()..collect(resolved);
  final theme = _PrinterTheme.of(resolved);
  final String video;
  _theme = theme;
  _clipLaneMix = {..._laneGains(resolved), for (final lane in _mutedLaneIds(resolved)) lane: 0};
  try {
    video = _video(resolved, anchors);
  } finally {
    _theme = null;
    _clipLaneMix = const {};
  }
  final buffer = StringBuffer();
  if (theme != null && theme.resolved) {
    buffer.writeln('// theme tokens resolved to literals for the printed build');
  }
  for (final name in resolution.applied) {
    buffer.writeln('// master "$name" applied for the printed build');
  }
  final stepsNotes = _stepsNotesComment(resolved);
  if (stepsNotes != null) buffer.writeln(stepsNotes);
  final lanes = _lanesComment(resolved);
  if (lanes != null) buffer.writeln(lanes);
  buffer
    ..writeln("import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;")
    ..writeln("import 'package:fluvie/fluvie.dart';")
    ..writeln()
    ..writeln('Video build() {');
  for (final declaration in anchors.declarations) {
    buffer.writeln('  $declaration');
  }
  buffer
    ..writeln('  return $video;')
    ..writeln('}');
  return DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
    pageWidth: 100,
  ).format(buffer.toString());
}

String _video(Map<String, Object?> spec, _Anchors anchors) {
  final fps = spec['fps'];
  final muted = _mutedLaneIds(spec);
  final gains = _laneGains(spec);
  final args = <String?>[
    if (spec['size'] != null) 'size: ${_videoSize(spec['size'])}',
    if (fps is int && fps != 30) 'fps: $fps',
    if (spec['poster'] != null) 'poster: ${_time(spec['poster']! as String)}',
    if (spec['export'] != null) 'export: ${_export(_map(spec['export']))}',
    if (_effectiveMotionDefaults(spec) case final Map<String, Object?> defaults)
      'motionDefaults: ${_defaults(defaults)}',
    if (spec['transition'] != null) 'transition: ${_transition(_map(spec['transition']))}',
    _audioArg(spec['audio'], anchors, muted: muted, gains: gains),
    _overlaysArg(spec['overlays'], anchors),
    'scenes: [${_scenes(spec['scenes'], anchors, muted: muted, gains: gains)}]',
  ];
  return 'Video(${_args(args)})';
}

/// A safely quoted JSON-shaped Dart literal for additive spec-only features.
String _jsonLiteral(Object? value) => switch (value) {
  null => 'null',
  final String text => _str(text),
  final num number => '$number',
  final bool boolean => '$boolean',
  final List<Object?> items => '[${items.map(_jsonLiteral).join(', ')}]',
  final Map<String, Object?> items =>
    '<String, Object?>{${items.entries.map((entry) => '${_str(entry.key)}: ${_jsonLiteral(entry.value)}').join(', ')}}',
  _ => throw FormatException('Expected a JSON value, received $value'),
};

String _scenes(
  Object? scenes,
  _Anchors anchors, {
  Set<String> muted = const {},
  Map<String, double> gains = const {},
}) {
  if (scenes is! List) return '';
  return [
    for (final scene in scenes) _scene(_map(scene), anchors, muted: muted, gains: gains),
  ].join(', ');
}

String _scene(
  Map<String, Object?> scene,
  _Anchors anchors, {
  Set<String> muted = const {},
  Map<String, double> gains = const {},
}) {
  final args = <String?>[
    'duration: ${_time(scene['duration']! as String)}',
    if (scene['background'] != null) 'background: ${_background(_map(scene['background']))}',
    if (scene['enter'] != null) 'enter: ${_transition(_map(scene['enter']))}',
    if (scene['exit'] != null) 'exit: ${_transition(_map(scene['exit']))}',
    if (scene['motionDefaults'] != null)
      'motionDefaults: ${_defaults(_map(scene['motionDefaults']))}',
    _audioArg(scene['audio'], anchors, muted: muted, gains: gains),
    _sceneChildrenArg(scene, anchors),
  ];
  return 'Scene(${_args(args)})';
}

Map<String, double> _clipLaneMix = const {};

String? _sceneChildrenArg(Map<String, Object?> scene, _Anchors anchors) {
  final transitions = scene['transitions'];
  if (transitions is! List || transitions.isEmpty) return _childrenArg(scene['children'], anchors);
  final children = (scene['children'] as List<Object?>?) ?? const [];
  final edges = transitions
      .map((raw) {
        final edge = _map(raw);
        final between = edge['between']! as List<Object?>;
        if (between.length != 2) {
          throw const FormatException('Clip transitions need exactly two element ids.');
        }
        return 'ClipTransition(outgoing: ${_str(between[0]! as String)}, incoming: ${_str(between[1]! as String)}, transition: ${_transition(edge)})';
      })
      .join(', ');
  return 'children: [ClipTransitionGroup(children: [${_elementItems(children, anchors)}], transitions: [$edges])]';
}

/// The `overlays:` argument of a `Video`, or null when there are none.
///
/// Overlays render, so they print as the `Video`'s own argument rather than as
/// a comment: they are elements outside every scene, and the printed Dart says
/// exactly that.
String? _overlaysArg(Object? overlays, _Anchors anchors) {
  if (overlays is! List || overlays.isEmpty) return null;
  return 'overlays: [${_elementItems(overlays, anchors)}]';
}

String? _childrenArg(Object? children, _Anchors anchors) {
  if (children is! List || children.isEmpty) return null;
  return 'children: [${_elementItems(children, anchors)}]';
}

Map<String, Object?> _map(Object? value) => value! as Map<String, Object?>;
