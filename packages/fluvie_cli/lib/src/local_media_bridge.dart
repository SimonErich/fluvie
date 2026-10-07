import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_media/native.dart';
import 'package:path/path.dart' as p;

part 'local_media_bridge_frames.dart';
part 'local_media_bridge_http.dart';
part 'local_media_bridge_upload.dart';

/// A session-owned loopback bridge from browser preview to native FFmpeg.
/// Source URLs are opaque IDs; callers never submit arbitrary native paths.
final class LocalMediaBridge {
  LocalMediaBridge._(
    this._server,
    this._directory,
    this._tools,
    this.projectDir,
    this.sessionToken,
  );

  /// Starts a random-port bridge, scoped to one preview and a random token.
  static Future<LocalMediaBridge> start({
    required FfmpegToolchain toolchain,
    required Directory projectDir,
  }) async {
    final directory = await Directory.systemTemp.createTemp('fluvie_preview_media_');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final random = Random.secure();
    final token = base64Url.encode(List<int>.generate(32, (_) => random.nextInt(256)));
    final bridge = LocalMediaBridge._(
      server,
      directory,
      FfmpegMediaTools(ffmpegPath: toolchain.ffmpegPath, ffprobePath: toolchain.ffprobePath),
      projectDir,
      token,
    );
    server.listen((request) {
      late final Future<void> handling;
      handling = bridge._handle(request).whenComplete(() => bridge._requests.remove(handling));
      bridge._requests.add(handling);
      unawaited(handling);
    });
    return bridge;
  }

  final HttpServer _server;
  final Directory _directory;
  final FfmpegMediaTools _tools;
  final _sources = <String, Future<_BridgeSource>>{};
  final _requests = <Future<void>>{};
  final _events = <HttpResponse>{};
  Future<File> Function()? _audioProvider;
  Future<File>? _audio;
  bool _closed = false;
  final _cancelled = Completer<void>();
  final _sessions = <String, FfmpegFrameSession>{};
  Future<void> _frameTail = Future.value();
  var _decoderStarts = 0;

  /// Original project used for dropped asset reads.
  final Directory projectDir;

  /// Unpredictable capability required for every request.
  final String sessionToken;

  /// HTTP origin for this preview session.
  Uri get endpoint => Uri(scheme: 'http', host: '127.0.0.1', port: _server.port);

  /// Audio cache revision; increments on composition or resource changes.
  int audioRevision = 0;

  /// Supplies the composition's prepared audio-only WAV mix.
  void setAudioProvider(Future<File> Function() provider) {
    _audioProvider = provider;
    invalidateAudio();
  }

  /// Invalidates the mixed audio when authoring changes.
  void invalidateAudio() {
    _audio = null;
    audioRevision++;
  }

  /// Announces a completed rebuild to browser hosts without a debug connection.
  void notifyReload() {
    invalidateAudio();
    for (final response in _events.toList()) {
      response.write('data: ${jsonEncode({'type': 'reload', 'audioRevision': audioRevision})}\n\n');
      unawaited(
        response.flush().catchError((Object _) {
          _events.remove(response);
        }),
      );
    }
  }

  /// Stops the server, FFmpeg children and temporary source storage.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _cancelled.complete();
    await _tools.closeAsync();
    await _frameTail;
    _sessions.clear();
    await Future.wait(
      _events.toList().map((response) async {
        try {
          await response.close();
        } on Object {
          /* The browser disconnected before session shutdown. */
        }
      }),
    );
    await _server.close(force: true);
    await Future.wait(_requests.toList());
    // Owned in-flight handlers finish their cleanup before storage disappears.
    if (_directory.existsSync()) await _directory.delete(recursive: true);
  }

  static Future<Uint8List> _body(HttpRequest request, {required int limit}) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      if (builder.length + chunk.length > limit) {
        throw const FormatException('Request body is too large.');
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  static void _json(HttpResponse response, Map<String, Object?> value) {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(value));
  }
}
