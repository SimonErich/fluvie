import 'package:dart_style/dart_style.dart';
import 'package:meta/meta.dart';

part 'dart_spec_printer_animations.dart';
part 'dart_spec_printer_backgrounds.dart';
part 'dart_spec_printer_elements.dart';
part 'dart_spec_printer_literals.dart';

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
/// both the element's `.animate(anchor: ...)` and any `Trigger.after(...)`,
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
  final anchors = _Anchors()..collect(spec);
  final buffer = StringBuffer()
    ..writeln("import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;")
    ..writeln("import 'package:fluvie/fluvie.dart';")
    ..writeln()
    ..writeln('Video build() {');
  for (final declaration in anchors.declarations) {
    buffer.writeln('  $declaration');
  }
  buffer
    ..writeln('  return ${_video(spec, anchors)};')
    ..writeln('}');
  return DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
    pageWidth: 100,
  ).format(buffer.toString());
}

String _video(Map<String, Object?> spec, _Anchors anchors) {
  final fps = spec['fps'];
  final args = <String?>[
    if (spec['size'] != null) 'size: ${_videoSize(spec['size'])}',
    if (fps is int && fps != 30) 'fps: $fps',
    if (spec['poster'] != null) 'poster: ${_time(spec['poster']! as String)}',
    if (spec['export'] != null) 'export: ${_export(_map(spec['export']))}',
    if (spec['motionDefaults'] != null)
      'motionDefaults: ${_defaults(_map(spec['motionDefaults']))}',
    if (spec['transition'] != null) 'transition: ${_transition(_map(spec['transition']))}',
    'scenes: [${_scenes(spec['scenes'], anchors)}]',
  ];
  return 'Video(${_args(args)})';
}

String _scenes(Object? scenes, _Anchors anchors) {
  if (scenes is! List) return '';
  return [for (final scene in scenes) _scene(_map(scene), anchors)].join(', ');
}

String _scene(Map<String, Object?> scene, _Anchors anchors) {
  final args = <String?>[
    'duration: ${_time(scene['duration']! as String)}',
    if (scene['background'] != null) 'background: ${_background(_map(scene['background']))}',
    if (scene['enter'] != null) 'enter: ${_transition(_map(scene['enter']))}',
    if (scene['exit'] != null) 'exit: ${_transition(_map(scene['exit']))}',
    if (scene['motionDefaults'] != null)
      'motionDefaults: ${_defaults(_map(scene['motionDefaults']))}',
    _childrenArg(scene['children'], anchors),
  ];
  return 'Scene(${_args(args)})';
}

String? _childrenArg(Object? children, _Anchors anchors) {
  if (children is! List || children.isEmpty) return null;
  final items = [for (final child in children) _element(_map(child), anchors)].join(', ');
  return 'children: [$items]';
}

/// Collects every anchor id a document references and assigns each a unique,
/// readable Dart variable, so the printed code declares one `Anchor` per id and
/// reuses it (anchors are compared by reference, never value).
class _Anchors {
  final Map<String, String> _variables = {};
  final Set<String> _used = {};

  /// The `final <name> = Anchor('<id>');` lines, in first-seen order.
  final List<String> declarations = [];

  /// Walks [spec] gathering ids from element `anchor` fields and the anchors
  /// that `after`/`whenStarts`/`beat` triggers reference.
  void collect(Map<String, Object?> spec) {
    final scenes = spec['scenes'];
    if (scenes is! List) return;
    for (final scene in scenes) {
      if (scene is! Map<String, Object?>) continue;
      final children = scene['children'];
      if (children is! List) continue;
      for (final child in children) {
        if (child is! Map<String, Object?>) continue;
        final anchor = child['anchor'];
        if (anchor is String) variableFor(anchor);
        final animate = child['animate'];
        if (animate is! List) continue;
        for (final animation in animate) {
          if (animation is Map<String, Object?>) _collectTrigger(animation['at']);
        }
      }
    }
  }

  void _collectTrigger(Object? at) {
    if (at is! Map<String, Object?>) return;
    final reference = switch (at['kind']) {
      'after' || 'whenStarts' => at['anchor'],
      'beat' => at['track'],
      _ => null,
    };
    if (reference is String) variableFor(reference);
  }

  /// The variable naming the anchor with [id], declaring it on first use.
  String variableFor(String id) => _variables[id] ??= _declare(id);

  String _declare(String id) {
    final name = _uniqueName(_identifier(id));
    _used.add(name);
    declarations.add('final $name = Anchor(${_str(id)});');
    return name;
  }

  String _uniqueName(String base) {
    if (!_used.contains(base) && !_dartReserved.contains(base)) return base;
    var index = 1;
    while (_used.contains('$base$index')) {
      index++;
    }
    return '$base$index';
  }
}

/// Turns an anchor id into a lower-camel Dart identifier, falling back to a safe
/// name when the id has no usable letters.
String _identifier(String id) {
  final parts = id.split(RegExp('[^A-Za-z0-9]+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'anchor';
  final head = parts.first.toLowerCase();
  final tail = parts.skip(1).map((part) => part[0].toUpperCase() + part.substring(1)).join();
  final name = '$head$tail';
  return RegExp('^[0-9]').hasMatch(name) ? 'a$name' : name;
}

const Set<String> _dartReserved = {
  'assert',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'default',
  'do',
  'else',
  'enum',
  'extends',
  'false',
  'final',
  'finally',
  'for',
  'if',
  'in',
  'is',
  'new',
  'null',
  'rethrow',
  'return',
  'super',
  'switch',
  'this',
  'throw',
  'true',
  'try',
  'var',
  'void',
  'while',
  'with',
  'build',
  'Video',
};

Map<String, Object?> _map(Object? value) => value! as Map<String, Object?>;
