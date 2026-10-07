import 'package:flutter/foundation.dart' show immutable, mapEquals;

part 'media_store_kind.dart';
part 'media_store_entry_codec.dart';

/// One imported media file, tracked in the document's `editor.media` block so
/// the asset panel can offer it for reuse and a bundle save knows what to
/// pack.
///
/// The entry is editor metadata (the render digest excludes it); the
/// render-affecting reference is the `{kind, value}` [source] the placed
/// elements carry. On desktop that is a `file` source; a web import registers
/// its bytes in the session media store and references them with a `bundle`
/// source.
@immutable
final class MediaStoreEntry {
  /// Creates an entry: the minted [id], the imported file's [name], its
  /// [kind], the spec [source] elements reference it by, and — where the
  /// importer knows them — the byte [sizeBytes] and the probed [duration]
  /// (a spec time string).
  const MediaStoreEntry({
    required this.id,
    required this.name,
    required this.kind,
    required this.source,
    this.sizeBytes,
    this.duration,
    this.folder,
    this.width,
    this.height,
    this.fps,
    this.channels,
    this.inFrames,
    this.outFrames,
  });

  /// Reads an entry from its `editor.media` JSON form.
  ///
  /// Throws a [FormatException] for a missing field or an unknown kind.
  factory MediaStoreEntry.fromJson(Map<String, Object?> json) => _mediaStoreEntryFromJson(json);

  /// The entry's identity inside the store (`media-N`, minted by the
  /// document).
  final String id;

  /// The imported file's display name (`b-roll.mp4`).
  final String name;

  /// What the file is, deciding how the editor offers it.
  final MediaStoreKind kind;

  /// The spec `{kind, value}` source placed elements reference this media by.
  final Map<String, Object?> source;

  /// The file's size in bytes, when the importer knew it.
  final int? sizeBytes;

  /// The probed duration as a spec time string, when a prober supplied one.
  final String? duration;

  /// The bin folder this entry is filed under, or null when it is unfiled.
  ///
  /// A flat name rather than a path: a bin is a way to find things, and nested
  /// folders make finding harder, not easier, once there are more than a
  /// handful of files.
  final String? folder;

  /// The probed pixel width, when a prober supplied one.
  final int? width;

  /// The probed pixel height, when a prober supplied one.
  final int? height;

  /// The probed source frame rate, when a prober supplied one.
  final double? fps;

  /// The number of source audio channels, when probed.
  final int? channels;

  /// The in point marked on this asset, in source frames, or null for the
  /// start of the file.
  ///
  /// Marked on the asset rather than on a placement, so marking once and
  /// placing three times gives three clips of the same range. Placing writes
  /// the range into the element's own `trim`; this is only the bin's memory of
  /// what the author picked.
  final int? inFrames;

  /// The out point marked on this asset, in source frames, or null for the end
  /// of the file.
  final int? outFrames;

  /// The probed duration in source frames, when both the duration and the rate
  /// are known.
  int? get durationFrames {
    final rate = fps;
    final spec = duration;
    if (rate == null || !rate.isFinite || rate <= 0 || spec == null) return null;
    final seconds = _secondsOf(spec);
    return seconds == null || !seconds.isFinite || seconds <= 0 ? null : (seconds * rate).round();
  }

  /// The marked range in source frames, defaulting to the whole file.
  ///
  /// Returns null when the range cannot be resolved — an out point with no
  /// known duration behind it, say — rather than inventing a bound.
  ({int start, int end})? get markedRange {
    final total = durationFrames;
    final start = inFrames ?? 0;
    final end = outFrames ?? total;
    if (end == null || end <= start) return null;
    return (start: start, end: end);
  }

  /// A copy with the named fields replaced; pass a clear flag to unset one.
  MediaStoreEntry copyWith({
    String? folder,
    bool clearFolder = false,
    int? inFrames,
    int? outFrames,
    bool clearMarks = false,
  }) => MediaStoreEntry(
    id: id,
    name: name,
    kind: kind,
    source: source,
    sizeBytes: sizeBytes,
    duration: duration,
    folder: clearFolder ? null : (folder ?? this.folder),
    width: width,
    height: height,
    fps: fps,
    channels: channels,
    inFrames: clearMarks ? null : (inFrames ?? this.inFrames),
    outFrames: clearMarks ? null : (outFrames ?? this.outFrames),
  );

  /// The `editor.media` JSON form, optional fields elided.
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'source': Map<String, Object?>.of(source),
    if (sizeBytes != null) 'bytes': sizeBytes,
    if (duration != null) 'duration': duration,
    if (folder != null) 'folder': folder,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (fps != null) 'fps': fps,
    if (channels != null) 'channels': channels,
    if (inFrames != null) 'in': inFrames,
    if (outFrames != null) 'out': outFrames,
  };

  @override
  bool operator ==(Object other) =>
      other is MediaStoreEntry &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      mapEquals(other.source, source) &&
      other.sizeBytes == sizeBytes &&
      other.duration == duration &&
      other.folder == folder &&
      other.width == width &&
      other.height == height &&
      other.fps == fps &&
      other.channels == channels &&
      other.inFrames == inFrames &&
      other.outFrames == outFrames;

  @override
  int get hashCode => Object.hash(id, name, kind, source['kind'], source['value']);

  @override
  String toString() => 'MediaStoreEntry($id, $name, ${kind.name})';
}
