part of 'dart_spec_printer.dart';

/// Collects every anchor id a document references and assigns each a unique,
/// readable Dart variable, so the printed code declares one `Anchor` per id and
/// reuses it (anchors are compared by reference, never value).
class _Anchors {
  final Map<String, String> _variables = {};
  final Set<String> _used = {};

  /// The `final <name> = Anchor('<id>');` lines, in first-seen order.
  final List<String> declarations = [];

  /// Walks [spec] gathering ids from element `anchor` and `shared` fields,
  /// `Bars` and reactive-preset `track` props, the audio lists (a music
  /// track's beat-grid `track` id and any anchors an sfx `at` trigger names),
  /// and the anchors that `after`/`whenStarts`/`beat` triggers reference —
  /// everything must be gathered before printing, because the declarations
  /// are written ahead of the body.
  void collect(Map<String, Object?> spec) {
    _collectAudio(spec['audio']);
    // The overlays before the scenes, matching the argument order the printed
    // Video carries, so a declaration always precedes its first reference.
    final overlays = spec['overlays'];
    if (overlays is List) {
      for (final overlay in overlays) {
        if (overlay is Map<String, Object?>) _collectElement(overlay);
      }
    }
    final scenes = spec['scenes'];
    if (scenes is! List) return;
    for (final scene in scenes) {
      if (scene is! Map<String, Object?>) continue;
      _collectAudio(scene['audio']);
      final children = scene['children'];
      if (children is! List) continue;
      for (final child in children) {
        if (child is Map<String, Object?>) _collectElement(child);
      }
    }
  }

  /// One audio list's ids: a music track's `track` names a beat grid other
  /// triggers reference, and an sfx `at` is a full trigger — both must join
  /// the shared declarations before any body prints.
  void _collectAudio(Object? audio) {
    if (audio is! List) return;
    for (final track in audio) {
      if (track is! Map<String, Object?>) continue;
      final id = track['track'];
      if (track['kind'] == 'music' && id is String) variableFor(id);
      if (track['kind'] == 'sfx') _collectTrigger(track['at']);
    }
  }

  /// One element's ids, recursing into a wrapper's nested `child` and a
  /// group's `children` so an anchor declared anywhere in the tree gets its
  /// variable. Hidden elements are collected too: their print is omitted, but
  /// a trigger or a hero partner elsewhere may still reference the id.
  void _collectElement(Map<String, Object?> element) {
    final anchor = element['anchor'];
    if (anchor is String) variableFor(anchor);
    final shared = element['shared'];
    if (shared is String) variableFor(shared);
    final track = element['track'];
    if (element['type'] == 'Bars' && track is String) variableFor(track);
    final animate = element['animate'];
    if (animate is List) {
      for (final animation in animate) {
        if (animation is! Map<String, Object?>) continue;
        _collectTrigger(animation['at']);
        // The reactive presets name an `Audio.track` anchor in `track`, so it
        // must join the shared declarations before any body prints.
        final reactiveTrack = animation['track'];
        final preset = animation['preset'];
        if ((preset == 'pulse' || preset == 'scaleY') && reactiveTrack is String) {
          variableFor(reactiveTrack);
        }
      }
    }
    final child = element['child'];
    if (_childBearingTypes.contains(element['type']) && child is Map<String, Object?>) {
      _collectElement(child);
    }
    final children = element['children'];
    if (element['type'] == 'Group' && children is List) {
      for (final nested in children) {
        if (nested is Map<String, Object?>) _collectElement(nested);
      }
    }
  }

  void _collectTrigger(Object? at) {
    if (at is! Map<String, Object?>) return;
    final reference = switch (at['kind']) {
      'whenEnds' || 'whenStarts' => at['anchor'],
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
