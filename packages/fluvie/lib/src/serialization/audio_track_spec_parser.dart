part of 'audio_track_spec.dart';

// The audio track parser: the list reader `decodeAudioTracks` shares with
// `VideoSpec`/`SceneSpec`, the per-track kind dispatch, and the source shape
// checks that keep the declared kind honest against the engine's
// string-classification rule (`audioSourceFromString`).

/// Reads an `audio` list from [raw], resolving anchors through [anchors]:
/// null decodes to an empty list, anything but a list throws.
///
/// Throws a [FluvieSpecError] (located under [path]) for a non-list value or
/// a non-object entry; each entry parses via [AudioTrackSpec.fromJson].
List<AudioTrackSpec> decodeAudioTracks(
  Object? raw,
  AnchorTable anchors, {
  List<String> path = const [],
}) {
  if (raw == null) return const [];
  if (raw is! List) {
    throw FluvieSpecError('Expected "audio" to be a list of tracks', path: path);
  }
  final tracks = <AudioTrackSpec>[];
  for (var i = 0; i < raw.length; i++) {
    final entry = raw[i];
    if (entry is! Map<String, Object?>) {
      throw FluvieSpecError('Expected an audio track object', path: [...path, '$i']);
    }
    tracks.add(AudioTrackSpec.fromJson(entry, anchors, path: [...path, '$i']));
  }
  return tracks;
}

AudioTrackSpec _parseAudioTrack(Map<String, Object?> json, AnchorTable anchors, List<String> path) {
  final kind = json['kind'];
  if (kind != 'music' && kind != 'sfx') {
    throw FluvieSpecError(
      'Unknown audio track kind "$kind"; expected "music" or "sfx"',
      path: [...path, 'kind'],
    );
  }
  final origin = _parseAudioOrigin(json['source'], [...path, 'source']);
  final volume = _parseVolume(json['volume'], [...path, 'volume']);
  if (kind == 'sfx') {
    for (final key in const ['fadeIn', 'fadeOut', 'loop', 'trim', 'track']) {
      if (json.containsKey(key)) {
        throw FluvieSpecError(
          '"$key" belongs to music tracks only; Audio.sfx does not carry it',
          path: [...path, key],
        );
      }
    }
    final at = json['at'];
    return AudioTrackSpec.sfx(
      source: origin.source,
      bundle: origin.bundle,
      at: at == null ? null : decodeTrigger(at, anchors, path: [...path, 'at']),
      volume: volume,
      automation: decodeAudioAutomation(json['automation'], path: [...path, 'automation']),
      lane: _laneOf(json),
    );
  }
  final track = json['track'];
  if (track is! String?) {
    throw FluvieSpecError('A music "track" is an anchor id (a string)', path: [...path, 'track']);
  }
  final loop = json['loop'];
  if (loop is! bool?) {
    throw FluvieSpecError('A music "loop" is a boolean', path: [...path, 'loop']);
  }
  final fadeIn = json['fadeIn'];
  final fadeOut = json['fadeOut'];
  return AudioTrackSpec.music(
    at: json['at'] == null ? null : decodeTrigger(json['at'], anchors, path: [...path, 'at']),
    source: origin.source,
    bundle: origin.bundle,
    volume: volume,
    automation: decodeAudioAutomation(json['automation'], path: [...path, 'automation']),
    fadeIn: fadeIn == null ? null : decodeTime(fadeIn, path: [...path, 'fadeIn']),
    fadeOut: fadeOut == null ? null : decodeTime(fadeOut, path: [...path, 'fadeOut']),
    loop: loop ?? false,
    trim: _parseTrim(json['trim'], [...path, 'trim']),
    track: track == null ? null : anchors.resolve(track),
    lane: _laneOf(json),
  );
}

/// The lane id this track names, or null.
String? _laneOf(Map<String, Object?> json) =>
    json['lane'] is String ? json['lane']! as String : null;

/// A `{kind, value}` audio source, with the value's shape checked against the
/// declared kind: the built `Audio` carries a plain source string the engine
/// classifies by shape, so a kind the shape would not round-trip to (a
/// relative `file` path, an `asset` that looks like a path or URL, a hostless
/// `network` value) is rejected here instead of silently reclassified later.
/// A `bundle` kind stays unresolved — the value is bundle-relative and
/// resolves through `BundleMedia` when the track's source is read.
({AudioSource? source, String? bundle}) _parseAudioOrigin(Object? raw, List<String> path) {
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('An audio track needs a "source" object {kind, value}', path: path);
  }
  final value = raw['value'];
  if (value is! String || value.isEmpty) {
    throw FluvieSpecError(
      'An audio source needs a non-empty string "value"',
      path: [...path, 'value'],
    );
  }
  if (raw['kind'] == 'bundle') return (source: null, bundle: value);
  final valuePath = [...path, 'value'];
  switch (raw['kind']) {
    case 'asset':
      if (value.startsWith('/') || _isHttpUrl(value)) {
        throw FluvieSpecError(
          'An "asset" audio source is a bundle key like "audio/song.mp3", not a path or URL',
          path: valuePath,
        );
      }
      return (source: AudioSource.asset(value), bundle: null);
    case 'file':
      if (!value.startsWith('/')) {
        throw FluvieSpecError(
          'A "file" audio source needs an absolute path starting with "/"',
          path: valuePath,
        );
      }
      return (source: AudioSource.file(value), bundle: null);
    case 'network':
      final uri = Uri.tryParse(value);
      if (uri == null || !_isHttp(uri) || uri.host.isEmpty) {
        throw FluvieSpecError(
          'A "network" audio source needs an http(s) URL with a host',
          path: valuePath,
        );
      }
      return (source: AudioSource.network(uri), bundle: null);
  }
  throw FluvieSpecError(
    'Unknown audio source kind "${raw['kind']}"; expected "asset", "file", "network", or "bundle"',
    path: [...path, 'kind'],
  );
}

double _parseVolume(Object? raw, List<String> path) {
  if (raw == null) return 1;
  if (raw is! num || !raw.isFinite || raw < 0) {
    throw FluvieSpecError('An audio "volume" is a number from 0 up', path: path);
  }
  return raw.toDouble();
}

TimeRange? _parseTrim(Object? raw, List<String> path) {
  if (raw == null) return null;
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a "trim" object {from, to}', path: path);
  }
  return TimeRange(
    decodeTime(raw['from'], path: [...path, 'from']),
    decodeTime(raw['to'], path: [...path, 'to']),
  );
}

bool _isHttp(Uri uri) => uri.scheme == 'http' || uri.scheme == 'https';

bool _isHttpUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && _isHttp(uri);
}

Map<String, Object?> _encodeAudioSource(AudioSource source) => switch (source) {
  AssetAudioSource(:final name) => {'kind': 'asset', 'value': name},
  FileAudioSource(:final path) => {'kind': 'file', 'value': path},
  NetworkAudioSource(:final url) => {'kind': 'network', 'value': url.toString()},
  MemoryAudioSource() => throw FluvieSpecError(
    'A memory audio source has no JSON form; save it through a bundle instead',
  ),
};

String _trackId(Anchor anchor) {
  final id = anchor.debugName;
  if (id == null) {
    throw FluvieSpecError('A music track anchor has no id (debugName) to serialize');
  }
  return id;
}
