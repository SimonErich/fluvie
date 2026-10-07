import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_media/fluvie_media.dart' show defaultFrameBatchBytes;
import 'package:http/http.dart' as http;

/// Creates a browser decoder backed by the Fluvie CLI's local FFmpeg session.
/// It handles native codecs and alpha without WebCodecs or WASM installation.
/// Dispose the returned decoder when its preview session ends.
LocalFfmpegClipDecoder createLocalFfmpegClipDecoder({
  required Uri endpoint,
  required String sessionToken,
  http.Client? httpClient,
}) =>
    LocalFfmpegClipDecoder(endpoint: endpoint, sessionToken: sessionToken, httpClient: httpClient);

/// Token-authenticated native decoder adapter for a managed browser preview.
final class LocalFfmpegClipDecoder implements WebClipDecoder, WebClipTimelineDecoder {
  /// Creates a session decoder. The owning preview must call [dispose].
  LocalFfmpegClipDecoder({
    required this.endpoint,
    required this.sessionToken,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  /// Local bridge origin.
  final Uri endpoint;

  /// Session capability.
  final String sessionToken;
  final http.Client _client;
  final bool _ownsClient;
  final _sources = Expando<Future<Map<String, Object?>>>();
  bool _disposed = false;
  Map<String, String> get _headers => {'X-Fluvie-Token': sessionToken};

  Future<Map<String, Object?>> _source(Uint8List bytes) async {
    _checkOpen();
    final loading = _sources[bytes] ?? _upload(bytes);
    _sources[bytes] = loading;
    try {
      final source = await loading;
      _checkOpen();
      return source;
    } on Object {
      if (identical(_sources[bytes], loading)) _sources[bytes] = null;
      rethrow;
    }
  }

  Future<Map<String, Object?>> _upload(Uint8List bytes) async {
    final response = await _client
        .post(
          endpoint.resolve('/sources'),
          headers: {
            ..._headers,
            'Content-Type': 'application/octet-stream',
          },
          body: bytes,
        )
        .timeout(const Duration(minutes: 3));
    _check(response);
    return jsonDecode(response.body) as Map<String, Object?>;
  }

  @override
  Future<ClipMetadata> probe(Uint8List bytes) async {
    final metadata = await _source(bytes);
    return (
      fps: (metadata['fps']! as num).toDouble(),
      frameCount: metadata['frameCount']! as int,
      width: metadata['width']! as int,
      height: metadata['height']! as int,
      hasAudio: metadata['hasAudio']! as bool,
    );
  }

  @override
  Future<MediaTimeline?> probeTimeline(Uint8List bytes) async {
    final timeline = (await _source(bytes))['timeline'];
    return timeline is Map<String, Object?> ? MediaTimeline.fromJson(timeline) : null;
  }

  @override
  Future<Map<int, RawFrame>> extractFrames(
    Uint8List bytes,
    List<int> sourceFrames, {
    required int width,
    required int height,
  }) async {
    if (width <= 0 || height <= 0 || width * height * 4 > defaultFrameBatchBytes) {
      throw ArgumentError('Frame dimensions must fit in the native preview batch limit.');
    }
    _checkOpen();
    final sorted = sourceFrames.toSet().toList()..sort();
    if (sorted.isEmpty) return {};
    final metadata = await _source(bytes);
    final capacity = (defaultFrameBatchBytes ~/ (width * height * 4)).clamp(1, 512);
    final frames = <int, RawFrame>{};
    for (var offset = 0; offset < sorted.length; offset += capacity) {
      final indices = sorted.sublist(offset, (offset + capacity).clamp(0, sorted.length));
      final response = await _client
          .post(
            endpoint.resolve('/sources/${metadata['id']}/frames'),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode({'indices': indices, 'width': width, 'height': height}),
          )
          .timeout(const Duration(minutes: 3));
      _checkOpen();
      _check(response);
      final payload = response.bodyBytes;
      final frameBytes = width * height * 4;
      if (payload.length != indices.length * frameBytes) {
        throw FluvieRenderException(
          'Native preview returned ${payload.length} bytes; expected ${indices.length * frameBytes}.',
        );
      }
      for (var i = 0; i < indices.length; i++) {
        frames[indices[i]] = RawFrame(
          frameIndex: indices[i],
          width: width,
          height: height,
          rgba: Uint8List.sublistView(payload, i * frameBytes, (i + 1) * frameBytes),
        );
      }
    }
    return frames;
  }

  /// Releases HTTP connections owned by this decoder.
  void dispose() {
    _disposed = true;
    if (_ownsClient) _client.close();
  }

  void _checkOpen() {
    if (_disposed) throw StateError('The local FFmpeg decoder is disposed.');
  }

  static void _check(http.Response response) {
    if (response.statusCode != 200) {
      throw FluvieRenderException(
        'Local FFmpeg preview failed (${response.statusCode}): ${response.body}',
      );
    }
  }
}
