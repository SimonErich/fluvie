import 'dart:js_interop';
import 'dart:typed_data';

import 'package:fluvie/fluvie.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

/// Browser audio synchronized to the same composition clock as VideoPreview.
LocalPreviewAudioController createLocalPreviewAudioController({
  required Uri endpoint,
  required String sessionToken,
}) => LocalPreviewAudioController(endpoint: endpoint, sessionToken: sessionToken);

/// Plays the prepared native mix through WebAudio, correcting drift and seeks.
final class LocalPreviewAudioController implements PreviewAudioController {
  /// Creates an inactive controller. [activate] requires a user gesture.
  LocalPreviewAudioController({
    required this.endpoint,
    required this.sessionToken,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  /// Native bridge origin.
  final Uri endpoint;

  /// Preview session capability.
  final String sessionToken;
  final http.Client _client;
  final bool _ownsClient;
  web.AudioContext? _context;
  web.AudioBuffer? _buffer;
  web.AudioBufferSourceNode? _source;
  Future<void>? _loading;
  bool _disposed = false;
  double _startedAt = 0;
  double _startedPosition = 0;
  double _startedRate = 1;
  Duration _position = Duration.zero;
  bool _playing = false;
  double _rate = 1;

  @override
  Future<void> activate() async {
    if (_disposed) throw StateError('The preview audio controller is disposed.');
    final context = _context ??= web.AudioContext();
    // Resume immediately, before network awaits, while the gesture is active.
    final resume = context.resume().toDart;
    await resume;
    try {
      await (_loading ??= _load(context));
    } on Object {
      _loading = null;
      rethrow;
    }
    await synchronize(position: _position, playing: _playing, rate: _rate);
  }

  Future<void> _load(web.AudioContext context) async {
    final response = await _client
        .get(endpoint.resolve('/audio'), headers: {'X-Fluvie-Token': sessionToken})
        .timeout(const Duration(minutes: 3));
    if (response.statusCode != 200) {
      throw StateError('Preview audio mix failed (${response.statusCode}): ${response.body}');
    }
    final bytes = response.bodyBytes;
    final buffer = await context.decodeAudioData(Uint8List.fromList(bytes).buffer.toJS).toDart;
    if (!_disposed) _buffer = buffer;
  }

  /// Reloads a changed composition mix after audio was explicitly activated.
  Future<void> reload() async {
    final context = _context;
    if (context == null || _disposed) return;
    _stop();
    _buffer = null;
    _loading = _load(context);
    try {
      await _loading;
    } on Object {
      _loading = null;
      rethrow;
    }
    await synchronize(position: _position, playing: _playing, rate: _rate);
  }

  @override
  Future<void> synchronize({
    required Duration position,
    required bool playing,
    required double rate,
  }) async {
    if (_disposed) return;
    if (!rate.isFinite || rate <= 0) {
      throw ArgumentError.value(rate, 'rate', 'must be positive and finite');
    }
    _position = position;
    _playing = playing;
    _rate = rate;
    final context = _context;
    final buffer = _buffer;
    if (context == null || buffer == null) return;
    final seconds = (position.inMicroseconds / Duration.microsecondsPerSecond).clamp(
      0.0,
      buffer.duration,
    );
    if (!playing || seconds >= buffer.duration) {
      _stop();
      return;
    }
    final predicted = _startedPosition + (context.currentTime - _startedAt) * _startedRate;
    if (_source != null && _startedRate == rate && (predicted - seconds).abs() < 0.08) return;
    _stop();
    final source = context.createBufferSource()
      ..buffer = buffer
      ..playbackRate.value = rate
      ..connect(context.destination)
      ..start(0, seconds);
    _source = source;
    _startedAt = context.currentTime;
    _startedPosition = seconds;
    _startedRate = rate;
  }

  void _stop() {
    final source = _source;
    _source = null;
    if (source != null) {
      source
        ..stop()
        ..disconnect();
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _stop();
    if (_ownsClient) _client.close();
    final context = _context;
    _context = null;
    _buffer = null;
    if (context != null) await context.close().toDart;
  }
}
