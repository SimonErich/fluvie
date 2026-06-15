import 'dart:convert';

import 'package:fluvie/src/core/hash/fnv1a.dart';
import 'package:meta/meta.dart';

/// One declared audio origin, identified before it is decoded.
///
/// An `AudioSource` is kept deliberately **separate** from `MediaSource`: audio
/// is decoded to PCM and mixed in the encoder, not loaded as image bytes, so
/// widening `MediaSource` would break every switch over it. `Audio` exposes one
/// through `audioSource`, the collect pass gathers it, the `MediaResolver`
/// validates + allowlists + materializes it before frame 0, and the encoder
/// `-i`s the materialized file.
///
/// Each variant exposes a stable [cacheKey] — the FNV-1a-64 hash of a canonical
/// string that distinguishes every variant and its discriminating field (path
/// vs host) — so an identical declaration shares one cache entry while a
/// different file or host is a distinct one. It carries only Dart-core types, so
/// it satisfies the layering law and lives in `core`.
///
/// `Audio` and `MediaResolver` are named in prose, not as doc links, because
/// they live in layers above `core` and a link would invert the layering.
@immutable
sealed class AudioSource {
  const AudioSource();

  /// A bundled asset addressed by its bundle key [name]
  /// (for example `audio/song.mp3`).
  const factory AudioSource.asset(String name) = AssetAudioSource;

  /// A file on disk at the absolute or working-directory-relative [path].
  const factory AudioSource.file(String path) = FileAudioSource;

  /// A remote asset at [url]; only allowlisted hosts and schemes are fetched.
  const factory AudioSource.network(Uri url) = NetworkAudioSource;

  /// The canonical string that fully identifies this source's audio — hashed
  /// into [cacheKey]. Distinct for every field that changes the decoded PCM.
  String get _canonical;

  /// The path-safe content-hash key for the audio cache.
  String get cacheKey => fnv1a64Hex(utf8.encode(_canonical));
}

/// An [AudioSource] backed by a bundled asset key.
final class AssetAudioSource extends AudioSource {
  /// Creates an asset source addressed by its bundle key [name].
  const AssetAudioSource(this.name);

  /// The asset bundle key, for example `audio/song.mp3`.
  final String name;

  @override
  String get _canonical => 'asset|$name';

  @override
  bool operator ==(Object other) => other is AssetAudioSource && other.name == name;

  @override
  int get hashCode => Object.hash(AssetAudioSource, name);

  @override
  String toString() => 'AudioSource.asset($name)';
}

/// An [AudioSource] backed by a file on disk.
final class FileAudioSource extends AudioSource {
  /// Creates a file source at [path].
  const FileAudioSource(this.path);

  /// The file system path to read.
  final String path;

  @override
  String get _canonical => 'file|$path';

  @override
  bool operator ==(Object other) => other is FileAudioSource && other.path == path;

  @override
  int get hashCode => Object.hash(FileAudioSource, path);

  @override
  String toString() => 'AudioSource.file($path)';
}

/// An [AudioSource] backed by a remote URL.
final class NetworkAudioSource extends AudioSource {
  /// Creates a network source at [url].
  const NetworkAudioSource(this.url);

  /// The URL to fetch (subject to the network allowlist).
  final Uri url;

  /// The URL host, checked against the network allowlist before any fetch.
  String get host => url.host;

  @override
  String get _canonical => 'network|$url';

  @override
  bool operator ==(Object other) => other is NetworkAudioSource && other.url == url;

  @override
  int get hashCode => Object.hash(NetworkAudioSource, url);

  @override
  String toString() => 'AudioSource.network($url)';
}
