part of 'element_builder.dart';

/// An `Image` from its spec props: the source plus the presentation extras
/// (`fit`, `cornerRadius`, `crop`, `frame`).
Widget _image(Map<String, Object?> props) {
  final source = _mediaSource(props['source'], 'source');
  final fit = _fitOrNull(props['fit']);
  final cornerRadius = props['cornerRadius'] is num
      ? (props['cornerRadius']! as num).toDouble()
      : null;
  final crop = props['crop'] == null ? null : decodeRect(props['crop'], path: const ['crop']);
  final frame = props['frame'] == null ? null : _frame(props['frame']);
  return switch (source) {
    AssetSource(:final name) => Image.asset(
      name,
      fit: fit,
      cornerRadius: cornerRadius,
      crop: crop,
      frame: frame,
    ),
    NetworkSource(:final url) => Image.network(
      url,
      fit: fit,
      cornerRadius: cornerRadius,
      crop: crop,
      frame: frame,
    ),
    FileSource(:final path) => Image.file(
      path,
      fit: fit,
      cornerRadius: cornerRadius,
      crop: crop,
      frame: frame,
    ),
    // Only a bundle source resolves here (memory has no JSON form).
    MemorySource(:final bytes, :final debugLabel) => Image.memory(
      bytes,
      debugLabel: debugLabel,
      fit: fit,
      cornerRadius: cornerRadius,
      crop: crop,
      frame: frame,
    ),
  };
}

/// A `Clip` from its spec props: source, trim, fit, its audio volume
/// (`0` mutes), the playback speed, and the preview poster.
Widget _clip(Map<String, Object?> props) {
  final source = _mediaSource(props['source'], 'source');
  final trim = _trimOrNull(props['trim']);
  final fit = _fitOrNull(props['fit']);
  final audio = _clipAudio(props['volume'], props['fadeIn'], props['fadeOut'], props['automation']);
  final speedRamp = decodeClipSpeedRamp(props['speed']);
  final speed = speedRamp == null ? _clipSpeed(props['speed']) : 1.0;
  final poster = props['poster'] == null ? null : _mediaSource(props['poster'], 'poster');
  return switch (source) {
    AssetSource(:final name) => Clip.asset(
      name,
      trim: trim,
      fit: fit,
      audio: audio,
      poster: poster,
      speed: speed,
      speedRamp: speedRamp,
    ),
    NetworkSource(:final url) => Clip.network(
      url,
      trim: trim,
      fit: fit,
      audio: audio,
      poster: poster,
      speed: speed,
      speedRamp: speedRamp,
    ),
    FileSource(:final path) => Clip.file(
      path,
      trim: trim,
      fit: fit,
      audio: audio,
      poster: poster,
      speed: speed,
      speedRamp: speedRamp,
    ),
    // Only a bundle source resolves here (memory has no JSON form).
    MemorySource(:final bytes, :final debugLabel) => Clip.memory(
      bytes,
      debugLabel: debugLabel,
      trim: trim,
      fit: fit,
      audio: audio,
      poster: poster,
      speed: speed,
      speedRamp: speedRamp,
    ),
  };
}

/// A `{kind, value}` media source object — shared by images, clips, and
/// posters.
MediaSource _mediaSource(Object? raw, String field) {
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a "$field" object {kind, value}', path: [field]);
  }
  final value = raw['value'];
  if (value is! String) {
    throw FluvieSpecError('A media source needs a string "value"', path: [field, 'value']);
  }
  return switch (raw['kind']) {
    'asset' => MediaSource.asset(value),
    'network' => MediaSource.network(Uri.parse(value)),
    'file' => MediaSource.file(MediaFileBase.resolvePath(value)),
    'bundle' => BundleMedia.resolveMedia(value, path: [field, 'value']),
    _ => throw FluvieSpecError(
      'Unknown media source kind "${raw['kind']}"',
      path: [field, 'kind'],
    ),
  };
}

/// A `PhotoFrame` from a `{style, ...}` object; mirrors the widget factories.
PhotoFrame _frame(Object? raw) {
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a "frame" object {style, ...}', path: const ['frame']);
  }
  final caption = raw['caption'];
  return switch (raw['style']) {
    'none' => const PhotoFrame.none(),
    'rounded' => PhotoFrame.rounded(radius: _numOr(raw['radius'], 24).toDouble()),
    'card' => PhotoFrame.card(
      radius: _numOr(raw['radius'], 16).toDouble(),
      elevation: _numOr(raw['elevation'], 24).toDouble(),
    ),
    'polaroid' => PhotoFrame.polaroid(caption: caption is String ? caption : null),
    _ => throw FluvieSpecError(
      'Unknown frame style "${raw['style']}"',
      path: const ['frame', 'style'],
    ),
  };
}

TimeRange? _trimOrNull(Object? raw) {
  if (raw == null) return null;
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a "trim" object {from, to}', path: const ['trim']);
  }
  return TimeRange(
    decodeTime(raw['from'], path: const ['trim', 'from']),
    decodeTime(raw['to'], path: const ['trim', 'to']),
  );
}

/// A clip's playback rate: a non-zero number, negative to play the trim
/// backwards. Absent means source speed.
///
/// Zero is refused rather than silently frozen: it would advance no source
/// frames at all, which reads as a still and is better written as an `Image`.
double _clipSpeed(Object? speed) {
  if (speed == null) return 1;
  if (speed is! num || speed == 0 || !speed.toDouble().isFinite) {
    throw FluvieSpecError(
      'A clip "speed" is a non-zero number: 1 is source speed, 0.5 half, '
      '2 double, and a negative rate plays the trim backwards',
      path: const ['speed'],
    );
  }
  return speed.toDouble();
}

ClipAudio _clipAudio(Object? volume, Object? fadeIn, Object? fadeOut, Object? automation) {
  final envelope = decodeAudioAutomation(automation);
  final fade = fadeIn == null ? Time.zero : decodeTime(fadeIn, path: const ['fadeIn']);
  final out = fadeOut == null ? Time.zero : decodeTime(fadeOut, path: const ['fadeOut']);
  if (volume == null) return ClipAudio.included(fadeIn: fade, fadeOut: out, automation: envelope);
  if (volume is! num || volume < 0 || !volume.toDouble().isFinite) {
    throw FluvieSpecError('A clip "volume" is a number from 0 up', path: const ['volume']);
  }
  if (volume == 0) return const ClipAudio.muted();
  return ClipAudio.included(
    volume: volume.toDouble(),
    fadeIn: fade,
    fadeOut: out,
    automation: envelope,
  );
}

BoxFit? _fitOrNull(Object? raw) =>
    raw == null ? null : decodeEnum(BoxFit.values, raw, 'fit', path: const ['fit']);
