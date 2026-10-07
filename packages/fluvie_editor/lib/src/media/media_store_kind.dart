part of 'media_store_entry.dart';

/// What a media-store entry holds, deciding how the editor offers it: images
/// and videos insert as elements, audio waits for the timeline's tracks.
enum MediaStoreKind {
  /// A still image, inserted as an `Image` element.
  image,

  /// A video file, inserted as a `Clip` element.
  video,

  /// An audio file, offered to the deck's audio tracks.
  audio,
}
