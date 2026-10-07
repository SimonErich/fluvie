part of 'dart_spec_printer.dart';

/// The `audio:` argument of a `Video` or `Scene`, or null when [audio]
/// declares no tracks (the argument is omitted, like an empty children list).
///
/// Tracks on a muted lane are left out, exactly as `VideoSpec.build` leaves
/// them out. Printing a track the spec silences would hand back Dart that
/// renders a different mix from the document it came from.
String? _audioArg(
  Object? audio,
  _Anchors anchors, {
  Set<String> muted = const {},
  Map<String, double> gains = const {},
}) {
  if (audio is! List || audio.isEmpty) return null;
  final tracks = [
    for (final track in audio)
      if (!muted.contains(_map(track)['lane']))
        _audioTrack(_map(track), anchors, laneGain: gains[_map(track)['lane']] ?? 1),
  ];
  if (tracks.isEmpty) return null;
  return 'audio: [${tracks.join(', ')}]';
}

/// The ids of the lanes [spec] silences.
Set<String> _mutedLaneIds(Map<String, Object?> spec) {
  final lanes = spec['lanes'];
  if (lanes is! List) return const {};
  return {
    for (final lane in lanes)
      if (lane is Map<String, Object?> && lane['muted'] == true && lane['id'] is String)
        lane['id']! as String,
  };
}

/// One `Audio.music(...)`/`Audio.sfx(...)` literal, mirroring the spec
/// builder's field mapping: the source `value` is the constructor's source
/// string, times print through the `_time` sugar, a music `track` id prints
/// as its shared anchor variable (pre-collected by `_Anchors.collect`, so the
/// declaration exists even when no trigger references it), and an sfx `at`
/// prints through the shared trigger printer.
String _audioTrack(Map<String, Object?> track, _Anchors anchors, {double laneGain = 1}) {
  final source = _map(track['source']);
  final value = _str(source['value']! as String);
  final declared = track['volume'];
  final volume = laneGain == 1 ? declared : ((declared as num?)?.toDouble() ?? 1) * laneGain;
  final id = track['track'];
  return switch (track['kind']) {
    'music' =>
      'Audio.music(${_args([
        value,
        if (track['at'] != null) 'at: ${_trigger(track['at'], anchors)}',
        if (volume != null) 'volume: ${_num(volume)}',
        if (track['automation'] != null) 'automation: ${_audioAutomation(_map(track['automation']))}',
        if (track['fadeIn'] != null) 'fadeIn: ${_time(track['fadeIn']! as String)}',
        if (track['fadeOut'] != null) 'fadeOut: ${_time(track['fadeOut']! as String)}',
        if (track['loop'] == true) 'loop: true',
        if (track['trim'] != null) 'trim: ${_trimRange(_map(track['trim']))}',
        if (id is String) 'track: ${anchors.variableFor(id)}',
      ])})',
    'sfx' =>
      'Audio.sfx(${_args([
        value,
        if (track['at'] != null) 'at: ${_trigger(track['at'], anchors)}',
        if (volume != null) 'volume: ${_num(volume)}',
        if (track['automation'] != null) 'automation: ${_audioAutomation(_map(track['automation']))}',
      ])})',
    _ => throw FormatException('Unknown audio track kind "${track['kind']}"'),
  };
}

String _audioAutomation(Map<String, Object?> automation) {
  final volume = automation['volume'];
  if (volume is num) return 'AudioAutomation(values: [${_num(volume)}])';
  if (volume is! Map<String, Object?>) return 'AudioAutomation()';
  return 'AudioAutomation(${_args([
    'values: [${(volume['values']! as List<Object?>).map(_num).join(', ')}]',
    'positions: [${(volume['positions']! as List<Object?>).map((p) => _time(p! as String)).join(', ')}]',
    if (volume['easings'] case final List<Object?> easings) 'easings: [${easings.map(_ease).join(', ')}]',
  ])})';
}

Map<String, double> _laneGains(Map<String, Object?> spec) => {
  if (spec['lanes'] case final List<Object?> lanes)
    for (final lane in lanes)
      if (lane is Map<String, Object?> && lane['id'] is String && lane['gain'] is num)
        lane['id']! as String: (lane['gain']! as num).toDouble(),
};
