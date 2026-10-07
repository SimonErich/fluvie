part of 'scene_spec.dart';

// Structural scene decoding, using the original shared anchor table and paths.
SceneSpec _parseSceneSpec(
  Map<String, Object?> json,
  AnchorTable anchors, {
  List<String> path = const [],
}) {
  final durationRaw = json['duration'];
  if (durationRaw == null) {
    throw FluvieSpecError('A scene needs a "duration"', path: path);
  }
  final children = <ElementSpec>[];
  final childrenRaw = json['children'];
  if (childrenRaw is List) {
    for (var i = 0; i < childrenRaw.length; i++) {
      final child = childrenRaw[i];
      if (child is! Map<String, Object?>) {
        throw FluvieSpecError('Expected an element object', path: [...path, 'children', '$i']);
      }
      children.add(ElementSpec.fromJson(child, anchors, path: [...path, 'children', '$i']));
    }
  } else if (childrenRaw != null) {
    throw FluvieSpecError('Expected "children" to be a list', path: [...path, 'children']);
  }
  final background = json['background'];
  final enter = json['enter'];
  final exit = json['exit'];
  final motion = json['motionDefaults'];
  final notes = json['notes'];
  final layoutRaw = json['layout'];
  var layout = SceneLayout.stack;
  if (layoutRaw != null) {
    layout = switch (layoutRaw) {
      'stack' => SceneLayout.stack,
      'canvas' => SceneLayout.canvas,
      _ => throw FluvieSpecError(
        'Unknown layout "$layoutRaw"; expected "canvas" or "stack"',
        path: [...path, 'layout'],
      ),
    };
  }
  final master = _decodeMasterName(json['master'], path);
  return SceneSpec(
    duration: decodeTime(durationRaw, path: [...path, 'duration']),
    layout: layout,
    master: master,
    fills: _decodeFills(json['fills'], anchors, path, hasMaster: master != null),
    audio: decodeAudioTracks(json['audio'], anchors, path: [...path, 'audio']),
    background: background == null
        ? null
        : BackgroundSpec.fromJson(
            _object(background, [...path, 'background']),
            path: [...path, 'background'],
          ),
    children: children,
    transitions: _decodeElementTransitions(json['transitions'], [...path, 'transitions']),
    enter: enter == null ? null : decodeTransition(enter, path: [...path, 'enter']),
    exit: exit == null ? null : decodeTransition(exit, path: [...path, 'exit']),
    motionDefaults: motion == null
        ? null
        : decodeDefaults(motion, path: [...path, 'motionDefaults']),
    steps: _decodeSteps(json['steps'], [...path, 'steps']),
    notes: notes == null
        ? null
        : NotesSpec.fromJson(_object(notes, [...path, 'notes']), path: [...path, 'notes']),
  );
}
