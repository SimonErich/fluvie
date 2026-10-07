import 'dart:typed_data';

import 'package:fluvie/fluvie.dart' show AudioSource, MediaSource;

/// One materialized session entry, in both vocabularies the engine loads by:
/// the media source images and clips use, and the audio source tracks use.
/// The store files each entry under one of them by extension.
typedef SessionSources = ({MediaSource media, AudioSource audio});

/// Materializes one session entry ([value] is the bundle-relative
/// `media/<name>`, [bytes] the file's content) into engine-loadable sources:
/// memory sources on the web, files under a sandboxed temp directory on
/// desktop.
typedef SessionMaterializer = Future<SessionSources> Function(String value, Uint8List bytes);

/// The web (and test) materializer: the bytes stay in memory, named by their
/// bundle-relative value for errors.
Future<SessionSources> memorySessionMaterializer(String value, Uint8List bytes) async => (
  media: MediaSource.memory(bytes, debugLabel: value),
  audio: AudioSource.memory(bytes, debugLabel: value),
);
