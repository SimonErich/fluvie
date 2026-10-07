part of 'video_spec.dart';

// The VideoSpec parser: the document root's structural checks, scene and
// master parsing against one shared anchor table, and the cross-check that
// every adopting scene names a known master and fills only its slots.

VideoSpec _parseVideoSpec(Map<String, Object?> json) {
  final version = json['fluvieSpec'];
  if (version != null && version != VideoSpec.schemaVersion) {
    throw FluvieSpecError(
      'Unsupported fluvieSpec version $version; '
      'this build reads version ${VideoSpec.schemaVersion}',
    );
  }
  final anchors = AnchorTable();
  final lanes = _parseLanes(json['lanes']);
  final masters = decodeMasters(json['masters'], anchors, path: const ['masters']);
  final scenesRaw = json['scenes'];
  if (scenesRaw is! List || scenesRaw.isEmpty) {
    throw FluvieSpecError('A video needs a non-empty "scenes" list', path: const ['scenes']);
  }
  final scenes = <SceneSpec>[];
  for (var i = 0; i < scenesRaw.length; i++) {
    final scene = scenesRaw[i];
    if (scene is! Map<String, Object?>) {
      throw FluvieSpecError('Expected a scene object', path: ['scenes', '$i']);
    }
    scenes.add(SceneSpec.fromJson(scene, anchors, path: ['scenes', '$i']));
    final fps = json['fps'] is int ? json['fps']! as int : VideoDefaults.fps;
    if (scenes[i].transitions.isNotEmpty) {
      validateElementTransitions(
        scenes[i].children,
        scenes[i].transitions,
        anchors,
        fps: fps,
        durationFrames: resolveSceneDurationFrames(scenes[i].duration, fps, 'scene $i'),
        path: ['scenes', '$i'],
      );
    }
    _checkSceneLanes(scenes[i], lanes, ['scenes', '$i']);
    // Cross-check eagerly: an unknown master name or slot is a parse error,
    // not a surprise at build time. The resolved scene is discarded.
    resolveSceneMaster(scenes[i], masters, path: ['scenes', '$i']);
  }
  final overlays = _parseOverlays(json['overlays'], anchors, lanes);
  final audio = decodeAudioTracks(json['audio'], anchors, path: const ['audio']);
  for (var i = 0; i < audio.length; i++) {
    _checkLaneReference(audio[i].lane, lanes, ['audio', '$i', 'lane']);
  }
  final size = json['size'];
  final fps = json['fps'];
  final poster = json['poster'];
  final export = json['export'];
  final motion = json['motionDefaults'];
  final transition = json['transition'];
  final editor = json['editor'];
  return VideoSpec(
    scenes: scenes,
    anchors: anchors,
    masters: masters,
    audio: audio,
    lanes: lanes,
    overlays: overlays,
    editorData: editor is Map<String, Object?> ? editor : null,
    size: size == null ? VideoSize.reels : decodeVideoSize(size, path: const ['size']),
    fps: fps is int ? fps : VideoDefaults.fps,
    poster: poster == null ? null : decodeTime(poster, path: const ['poster']),
    export: export == null ? null : decodeExport(export, path: const ['export']),
    motionDefaults: motion == null ? null : decodeDefaults(motion, path: const ['motionDefaults']),
    transition: transition == null
        ? null
        : decodeTransition(transition, path: const ['transition']),
    theme: switch (json['theme']) {
      null => null,
      final Map<String, Object?> map => ThemeSpec.fromJson(map, path: const ['theme']),
      _ => throw FluvieSpecError('Expected a theme object', path: const ['theme']),
    },
  );
}

/// The document's lane declarations, refusing a list that would leave a
/// reference ambiguous.
List<LaneSpec> _parseLanes(Object? raw) {
  if (raw == null) return const [];
  if (raw is! List) {
    throw FluvieSpecError('Expected "lanes" to be a list', path: const ['lanes']);
  }
  final lanes = <LaneSpec>[];
  final seen = <String>{};
  for (var i = 0; i < raw.length; i++) {
    final entry = raw[i];
    if (entry is! Map<String, Object?>) {
      throw FluvieSpecError('Expected a lane object', path: ['lanes', '$i']);
    }
    final lane = LaneSpec.fromJson(entry, path: ['lanes', '$i']);
    // One id, one row. Two rows answering to one name would draw the same
    // clip twice and honour whichever mute was read last.
    if (!seen.add(lane.id)) {
      throw FluvieSpecError('Two lanes share the id "${lane.id}"', path: ['lanes', '$i']);
    }
    lanes.add(lane);
  }
  return lanes;
}

/// Every element in [scene] points at a lane the document declared.
void _checkSceneLanes(SceneSpec scene, List<LaneSpec> lanes, List<String> path) {
  for (var i = 0; i < scene.children.length; i++) {
    _checkLaneReference(scene.children[i].lane, lanes, [...path, 'children', '$i', 'lane']);
  }
}

/// [reference] names a declared lane, or nothing at all.
///
/// A reference to a lane that is not there is not a row a tool can draw on,
/// and silently dropping it would move the clip somewhere the author never
/// put it.
void _checkLaneReference(String? reference, List<LaneSpec> lanes, List<String> path) {
  if (reference == null) return;
  if (lanes.any((lane) => lane.id == reference)) return;
  throw FluvieSpecError('No lane is declared with the id "$reference"', path: path);
}

/// The document's overlays: scene-independent elements on the video's clock.
///
/// An overlay may not declare `shared`. A hero morph pairs two elements across
/// a cut; an overlay is one element for the whole video, so there is no cut
/// for it to cross and a pairing that named it would pair it with itself.
List<ElementSpec> _parseOverlays(Object? raw, AnchorTable anchors, List<LaneSpec> lanes) {
  if (raw == null) return const [];
  if (raw is! List) {
    throw FluvieSpecError('Expected "overlays" to be a list', path: const ['overlays']);
  }
  final overlays = <ElementSpec>[];
  for (var i = 0; i < raw.length; i++) {
    final entry = raw[i];
    if (entry is! Map<String, Object?>) {
      throw FluvieSpecError('Expected an overlay element object', path: ['overlays', '$i']);
    }
    _refuseShared(entry, ['overlays', '$i']);
    final overlay = ElementSpec.fromJson(entry, anchors, path: ['overlays', '$i']);
    _checkLaneReference(overlay.lane, lanes, ['overlays', '$i', 'lane']);
    overlays.add(overlay);
  }
  return overlays;
}

/// Refuses `shared` anywhere at or below [element].
///
/// The rule is about the whole subtree, not the top of it: a hero nested in an
/// overlay's group would parse, then find no scene to pair with at mount and
/// blame the scene at the other end of the pair — the one place the author did
/// nothing wrong.
void _refuseShared(Map<String, Object?> element, List<String> path) {
  if (element['shared'] != null) {
    throw FluvieSpecError(
      'An overlay cannot be "shared": it already runs the whole video, so '
      'there is no boundary for it to morph across',
      path: [...path, 'shared'],
    );
  }
  for (final entry in element.entries) {
    final value = entry.value;
    if (value is Map<String, Object?>) {
      _refuseShared(value, [...path, entry.key]);
    } else if (value is List) {
      for (var i = 0; i < value.length; i++) {
        final child = value[i];
        if (child is Map<String, Object?>) _refuseShared(child, [...path, entry.key, '$i']);
      }
    }
  }
}
