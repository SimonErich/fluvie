part of 'dart_spec_printer.dart';

/// The shared timing tail. [ambient] presets (spin/drift/kenBurns) read no
/// duration/ease/spring, so those are dropped to match their signatures.
/// [atName] renames the printed trigger parameter for the one constructor
/// (`Animation.keyframes`) whose `at:` names the stop positions instead.
List<String?> _tail(
  Map<String, Object?> animation,
  _Anchors anchors, {
  required bool ambient,
  String atName = 'at',
}) => [
  if (!ambient && animation['duration'] != null)
    'duration: ${_time(animation['duration']! as String)}',
  if (!ambient && animation['ease'] != null) 'ease: ${_ease(animation['ease'])}',
  if (!ambient && animation['spring'] != null) 'spring: ${_spring(animation['spring'])}',
  if (animation['delay'] != null) 'delay: ${_time(animation['delay']! as String)}',
  if (animation['at'] != null) '$atName: ${_trigger(animation['at'], anchors)}',
  if (animation['stagger'] != null) 'stagger: ${_stagger(_map(animation['stagger']))}',
  if (animation['repeat'] != null) 'repeat: ${_repeat(_map(animation['repeat']))}',
  if (animation['label'] != null) 'label: ${_str(animation['label']! as String)}',
];

/// A `Trigger` expression; anchor references resolve to the shared variables.
String _trigger(Object? raw, _Anchors anchors) {
  if (raw is String) {
    return switch (raw) {
      'auto' => 'Trigger.auto',
      'sceneStart' => 'Trigger.sceneStart',
      'sceneEnd' => 'Trigger.sceneEnd',
      'previous' => 'Trigger.previous',
      _ => throw FormatException('Unknown trigger "$raw"'),
    };
  }
  final map = _map(raw);
  switch (map['kind']) {
    case 'at':
      return 'Trigger.at(${_time(map['time']! as String)})';
    case 'beat':
      return 'Trigger.beat(${_args([
        if (map['every'] != null) 'every: ${_num(map['every'])}',
        if (map['track'] != null) 'track: ${anchors.variableFor(map['track']! as String)}',
      ])})';
    case 'whenEnds':
      return 'Trigger.whenEnds(${anchors.variableFor(map['anchor']! as String)})';
    case 'whenStarts':
      return 'Trigger.whenStarts(${anchors.variableFor(map['anchor']! as String)})';
  }
  throw FormatException('Unknown trigger kind "${map['kind']}"');
}
