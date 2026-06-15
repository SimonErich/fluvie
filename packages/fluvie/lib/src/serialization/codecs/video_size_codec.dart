import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/video_size.dart';

/// The named [VideoSize] presets, by name (`story` aliases `reels`).
const Map<String, VideoSize> namedVideoSizes = {
  'reels': VideoSize.reels,
  'story': VideoSize.story,
  'square': VideoSize.square,
  'hd': VideoSize.hd,
  'fourK': VideoSize.fourK,
};

/// The JSON form of a [VideoSize]: a preset name when it matches one, otherwise
/// a `{"width": .., "height": ..}` object.
Object encodeVideoSize(VideoSize size) {
  for (final entry in namedVideoSizes.entries) {
    if (entry.value == size) return entry.key;
  }
  return {'width': size.width, 'height': size.height};
}

/// Reads a [VideoSize] from a preset name or a `{width, height}` object in
/// [raw].
///
/// Throws a [FluvieSpecError] (located at [path]) for an unknown name or shape.
VideoSize decodeVideoSize(Object? raw, {List<String> path = const []}) {
  if (raw is String) {
    final size = namedVideoSizes[raw];
    if (size == null) {
      throw FluvieSpecError(
        'Unknown video size "$raw"; expected one of: ${namedVideoSizes.keys.join(', ')}, or {width, height}',
        path: path,
      );
    }
    return size;
  }
  if (raw is Map<String, Object?>) {
    final width = raw['width'];
    final height = raw['height'];
    if (width is int && height is int) return VideoSize(width, height);
  }
  throw FluvieSpecError('Expected a video size name or a {width, height} object', path: path);
}
