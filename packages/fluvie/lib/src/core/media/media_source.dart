import 'dart:typed_data';

import 'package:meta/meta.dart';

/// One declared piece of media, identified before it is resolved.
///
/// A `MediaSource` is the single key shared by `Image`, `Clip`, and
/// `Background.image`/`.video`: the collect pass gathers it from the widget
/// tree, the `MediaResolver` pre-resolves it to bytes, and paint reads the
/// cached result back by it. It carries only `dart:typed_data` and Dart-core
/// types, so it satisfies the layering law and lives in `core` (no IO, no
/// riverpod).
///
/// `Image`, `Clip` and `MediaResolver` are named in prose, not as doc links,
/// because they live in layers above `core` and would invert the layering.
///
/// The four variants cover the four honest origins: a bundled
/// [MediaSource.asset], an on-disk [MediaSource.file], a
/// [MediaSource.network] URL, and verbatim [MediaSource.memory] bytes. They
/// are value-equal so the cache deduplicates identical declarations; memory
/// is equal by the *identity* of its byte buffer (plus label), because two
/// distinct buffers with the same contents are two distinct loads.
@immutable
sealed class MediaSource {
  const MediaSource();

  /// A bundled asset addressed by its bundle key [name]
  /// (for example `fixtures/swatch.png`).
  const factory MediaSource.asset(String name) = AssetSource;

  /// A file on disk at the absolute or working-directory-relative [path].
  const factory MediaSource.file(String path) = FileSource;

  /// A remote asset at [url]; only allowlisted hosts and schemes are fetched.
  const factory MediaSource.network(Uri url) = NetworkSource;

  /// Verbatim [bytes] already in memory; [debugLabel] names it in errors and
  /// `toString`. Equality is by the identity of [bytes] plus [debugLabel].
  const factory MediaSource.memory(Uint8List bytes, {String? debugLabel}) = MemorySource;
}

/// A [MediaSource] backed by a bundled asset key.
final class AssetSource extends MediaSource {
  /// Creates an asset source addressed by its bundle key [name].
  const AssetSource(this.name);

  /// The asset bundle key, for example `fixtures/swatch.png`.
  final String name;

  @override
  bool operator ==(Object other) => other is AssetSource && other.name == name;

  @override
  int get hashCode => Object.hash(AssetSource, name);

  @override
  String toString() => 'MediaSource.asset($name)';
}

/// A [MediaSource] backed by a file on disk.
final class FileSource extends MediaSource {
  /// Creates a file source at [path].
  const FileSource(this.path);

  /// The file system path to read.
  final String path;

  @override
  bool operator ==(Object other) => other is FileSource && other.path == path;

  @override
  int get hashCode => Object.hash(FileSource, path);

  @override
  String toString() => 'MediaSource.file($path)';
}

/// A [MediaSource] backed by a remote URL.
final class NetworkSource extends MediaSource {
  /// Creates a network source at [url].
  const NetworkSource(this.url);

  /// The URL to fetch (subject to the network allowlist).
  final Uri url;

  @override
  bool operator ==(Object other) => other is NetworkSource && other.url == url;

  @override
  int get hashCode => Object.hash(NetworkSource, url);

  @override
  String toString() => 'MediaSource.network($url)';
}

/// A [MediaSource] backed by verbatim in-memory bytes.
final class MemorySource extends MediaSource {
  /// Creates a memory source over [bytes], optionally named by [debugLabel].
  const MemorySource(this.bytes, {this.debugLabel});

  /// The raw bytes, used verbatim with no IO.
  final Uint8List bytes;

  /// A human-readable name shown in errors and `toString`.
  final String? debugLabel;

  @override
  bool operator ==(Object other) =>
      other is MemorySource && identical(other.bytes, bytes) && other.debugLabel == debugLabel;

  @override
  int get hashCode => Object.hash(MemorySource, identityHashCode(bytes), debugLabel);

  @override
  String toString() => 'MediaSource.memory(${debugLabel ?? 'unnamed'}, ${bytes.length} bytes)';
}
