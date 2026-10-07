import 'package:fluvie/src/core/media/media_source.dart';

/// Whether [source]'s name reads as a clip (a video container) rather than an
/// image, by file extension.
///
/// The image pre-resolve pass uses it to skip the image decode for clip
/// sources (those resolve through the clip path instead), and the web resolver
/// uses it to fail fast with a clear "clips are not supported on web" error.
/// A memory source has no path, so its `debugLabel` carries the name — a
/// `Clip.memory` names its bytes (`cam.mp4`) and classifies as a clip; an
/// unlabelled memory source stays an image.
bool isClipSource(MediaSource source) {
  final name = switch (source) {
    AssetSource(:final name) => name,
    FileSource(:final path) => path,
    NetworkSource(:final url) => url.path,
    MemorySource(:final debugLabel) => debugLabel ?? '',
  };
  final lower = name.toLowerCase();
  return lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.webm');
}
