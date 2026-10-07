part of 'element_spec.dart';

// The parsing half of ElementSpec: `ElementSpec.fromJson` delegates here so
// the data class stays a readable field list. Everything the parser accepts
// re-serializes canonically through `ElementSpec.toJson`.

/// Reads one element from [json] (see `ElementSpec.fromJson` for the
/// contract), resolving animation anchors through [anchors] and locating
/// every error under [path].
ElementSpec _parseElement(Map<String, Object?> json, AnchorTable anchors, List<String> path) {
  if (json['type'] == 'Clip' && json['speed'] is Map) {
    decodeClipSpeedRamp(json['speed'], path: [...path, 'speed']);
  }
  final type = json['type'];
  if (type is! String) {
    throw FluvieSpecError('An element needs a "type"', path: path);
  }
  if (type == 'Placeholder') {
    throw FluvieSpecError(
      'A Placeholder is legal only inside a master\'s "children"; '
      'a scene fills its slots through "fills"',
      path: path,
    );
  }
  if (!knownElementTypes.contains(type)) {
    throw FluvieSpecError('Unknown element "$type"', path: path);
  }
  final animate = <AnimationSpec>[];
  final animateRaw = json['animate'];
  if (animateRaw is List) {
    for (var i = 0; i < animateRaw.length; i++) {
      final entry = animateRaw[i];
      if (entry is! Map<String, Object?>) {
        throw FluvieSpecError('Expected an animation object', path: [...path, 'animate', '$i']);
      }
      animate.add(AnimationSpec.fromJson(entry, anchors, path: [...path, 'animate', '$i']));
    }
  } else if (animateRaw != null) {
    throw FluvieSpecError('Expected "animate" to be a list', path: [...path, 'animate']);
  }
  final show = _decodeShow(json['show'], path);
  final anchorId = json['anchor'];
  final sharedId = json['shared'];
  final visible = json['visible'];
  final id = json['id'];
  final transform = json['transform'];
  final props = <String, Object?>{
    for (final entry in json.entries)
      if (!ElementSpec.reservedElementKeys.contains(entry.key)) entry.key: entry.value,
  };
  return ElementSpec(
    type: type,
    props: props,
    id: id is String ? id : null,
    placement: transform == null ? null : decodePlacement(transform, path: [...path, 'transform']),
    anchor: anchorId is String ? anchorId : null,
    shared: sharedId is String ? sharedId : null,
    visible: visible != false,
    showFrom: show.from,
    showTo: show.to,
    animate: animate,
    lane: json['lane'] is String ? json['lane']! as String : null,
    effects: _parseEffects(json['effects'], path),
  );
}

/// Reads the `show` window bounds: an object with at least one of `from`
/// and `to`. An empty object is a parse error — `show()` with no bounds
/// changes nothing in the runtime, so canonicalization removes the key
/// instead of carrying residue.
({Time? from, Time? to}) _decodeShow(Object? raw, List<String> path) {
  if (raw == null) return (from: null, to: null);
  final showPath = [...path, 'show'];
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError(
      'Expected "show" to be an object with "from" and/or "to"',
      path: showPath,
    );
  }
  if (raw['from'] == null && raw['to'] == null) {
    throw FluvieSpecError(
      'A "show" needs at least one bound; drop the key to keep the '
      'element alive for the whole scene',
      path: showPath,
    );
  }
  return (
    from: raw['from'] == null ? null : decodeTime(raw['from'], path: [...showPath, 'from']),
    to: raw['to'] == null ? null : decodeTime(raw['to'], path: [...showPath, 'to']),
  );
}

/// The element's effect stack, refusing a shape that would render something
/// its author never wrote.
List<EffectSpec> _parseEffects(Object? raw, List<String> path) {
  if (raw == null) return const [];
  if (raw is! List) {
    throw FluvieSpecError('Expected "effects" to be a list', path: [...path, 'effects']);
  }
  return [
    for (var i = 0; i < raw.length; i++)
      if (raw[i] case final Map<String, Object?> effect)
        EffectSpec.fromJson(effect, path: [...path, 'effects', '$i'])
      else
        throw FluvieSpecError('Expected an effect object', path: [...path, 'effects', '$i']),
  ];
}
