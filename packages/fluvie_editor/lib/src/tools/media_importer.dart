import 'package:flutter/foundation.dart' show immutable, mapEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One picked (or scanned) media file, in the spec's own source form.
@immutable
final class MediaPick {
  /// Creates a pick of [source] (`{kind, value}` JSON); [isVideo] routes it
  /// to a `Clip` instead of an `Image`, [isAudio] to the media store only.
  /// A fresh import carries the file's [name] (and [sizeBytes] where known)
  /// so the store can record it; a reuse pick carries neither.
  const MediaPick({
    required this.source,
    required this.isVideo,
    this.isAudio = false,
    this.name,
    this.sizeBytes,
    this.duration,
    this.width,
    this.height,
    this.fps,
    this.channels,
  });

  /// The spec `{kind, value}` source object.
  final Map<String, Object?> source;

  /// Whether the media is a video.
  final bool isVideo;

  /// Whether the media is audio (stored for the deck's tracks, never an
  /// element).
  final bool isAudio;

  /// The imported file's name, or null for a reuse pick.
  final String? name;

  /// The imported file's size in bytes, where the importer knew it.
  final int? sizeBytes;

  /// Probed source duration, dimensions and source marking rate.
  final String? duration;

  /// Probed source pixel width.
  final int? width;

  /// Probed source pixel height.
  final int? height;

  /// Source marking rate (milliseconds for audio).
  final double? fps;

  /// The probed source audio channel count.
  final int? channels;

  @override
  bool operator ==(Object other) =>
      other is MediaPick &&
      other.isVideo == isVideo &&
      other.isAudio == isAudio &&
      other.name == name &&
      other.sizeBytes == sizeBytes &&
      other.duration == duration &&
      other.width == width &&
      other.height == height &&
      other.fps == fps &&
      other.channels == channels &&
      mapEquals(other.source, source);

  @override
  int get hashCode => Object.hash(
    isVideo,
    isAudio,
    name,
    sizeBytes,
    duration,
    width,
    height,
    fps,
    channels,
    source['kind'],
    source['value'],
  );

  @override
  String toString() => 'MediaPick($source, isVideo: $isVideo, isAudio: $isAudio)';
}

/// How the media tool obtains a file — the app supplies the platform picker,
/// tests supply fakes.
// ignore: one_member_abstracts, implementations hold platform pickers and their state; this is an object seam, not a function.
abstract interface class MediaImporter {
  /// Picks one media file, or returns null when the user cancels.
  Future<MediaPick?> pickMedia();
}

/// The importer the media tool uses; null (the default) disables the tool
/// until an app wires a real picker in.
final mediaImporterProvider = Provider<MediaImporter?>((ref) => null);
