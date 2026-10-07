import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fluvie_editor/fluvie_editor.dart' show MediaImporter, MediaPick;
import 'package:slides/editor/dropped_media_io.dart'
    if (dart.library.js_interop) 'package:slides/editor/dropped_media_web.dart';
import 'package:slides/editor/media_probe_io.dart'
    if (dart.library.js_interop) 'package:slides/editor/media_probe_web.dart';

/// The image extensions the media tool accepts.
const Set<String> imageExtensions = {'png', 'jpg', 'jpeg', 'webp', 'gif'};

/// The video extensions the media tool accepts.
const Set<String> videoExtensions = {'mp4', 'mov', 'webm'};

/// The audio extensions the media tool accepts (stored for the deck's
/// tracks, never placed on the canvas).
const Set<String> audioExtensions = {'mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'};

String _extension(String name) => name.split('.').last.toLowerCase();

/// Whether [name] looks like a video file.
bool isVideoName(String name) => videoExtensions.contains(_extension(name));

/// Whether [name] looks like an audio file.
bool isAudioName(String name) => audioExtensions.contains(_extension(name));

/// Whether [name] is media the editor can import.
bool isMediaName(String name) =>
    isVideoName(name) || isAudioName(name) || imageExtensions.contains(_extension(name));

/// Turns a picked or dropped file into a spec media source: the real [path]
/// when the platform gives one, else the bytes are materialized (a temp
/// file on desktop; a session-store `bundle` source on the web). The pick
/// carries the file's name and size so the media store can record the
/// import. Returns null for a non-media [name] or an empty payload.
Future<MediaPick?> mediaPickFor({required String name, String? path, List<int>? bytes}) async {
  if (!isMediaName(name)) return null;
  final video = isVideoName(name);
  final audio = isAudioName(name);
  if (path == null && (bytes == null || bytes.isEmpty)) return null;
  final source = path != null
      ? <String, Object?>{'kind': 'file', 'value': path}
      : await materializeDroppedMedia(name, bytes!);
  final metadata = await probeImportedMedia(
    path: source['kind'] == 'file' ? source['value'] as String? : null,
    bytes: bytes == null ? null : Uint8List.fromList(bytes),
    video: video,
    audio: audio,
  );
  return MediaPick(
    source: source,
    isVideo: video,
    isAudio: audio,
    name: name,
    sizeBytes: bytes?.length,
    duration: metadata.duration,
    width: metadata.width,
    height: metadata.height,
    fps: metadata.fps,
    channels: metadata.channels,
  );
}

/// The platform media picker behind the editor's media tool.
final class FileMediaImporter implements MediaImporter {
  // coverage:ignore-start the real picker needs a live platform channel
  @override
  Future<MediaPick?> pickMedia() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [...imageExtensions, ...videoExtensions, ...audioExtensions],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    if (file == null) return null;
    return mediaPickFor(name: file.name, path: file.path, bytes: file.bytes);
  }

  // coverage:ignore-end
}
