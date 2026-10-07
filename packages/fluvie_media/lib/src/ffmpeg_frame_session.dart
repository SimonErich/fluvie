part of 'ffmpeg_media_tools.dart';

/// A bounded forward reader that owns and reuses one native decoder.
///
/// Requests are serialized. Forward requests reuse decoded position; backward
/// requests seek to an indexed keyframe. Pixels are exact source ordinals, including
/// alpha and display rotation. Close the session when its source is released.
final class FfmpegFrameSession {
  FfmpegFrameSession._(
    this._tools,
    this._source,
    this.width,
    this.height,
    this._index,
    this._decoder,
  );

  final FfmpegMediaTools _tools;
  final String _source;
  final _SourceFrameIndex _index;
  final String? _decoder;

  /// Output raster dimensions requested by the caller.
  final int width;

  /// Output raster height requested by the caller.
  final int height;

  /// Exact source display timing.
  MediaTimeline get timeline => _index.timeline;

  /// Decoder starts, exposed for performance diagnostics.
  int get decoderStarts => _starts;

  /// Source pictures consumed from the pipe, including discarded pictures.
  int get framesRead => _framesRead;
  var _framesRead = 0;
  var _starts = 0;
  var _nextIndex = 0;
  var _closed = false;
  var _cancelled = false;
  Process? _process;
  StreamIterator<List<int>>? _bytes;
  List<int> _chunk = const [];
  var _offset = 0;
  var _stderr = '';
  Future<void>? _stderrDone;
  Future<void> _pending = Future.value();
  Future<void>? _closing;
  MediaFrame? _last;

  /// Reads sorted unique source ordinals without duplicating missing frames.
  Future<Map<int, MediaFrame>> readFrames(Iterable<int> indices) {
    final requested = indices.toSet().toList()..sort();
    final operation = _pending.then((_) => _readFrames(requested));
    _pending = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<Map<int, MediaFrame>> _readFrames(List<int> indices) async {
    _checkOpen();
    final frames = <int, MediaFrame>{};
    for (final index in indices) {
      RangeError.checkValidIndex(index, timeline, 'frameIndex', timeline.frameCount);
      if (_last?.frameIndex == index) {
        frames[index] = _last!;
        continue;
      }
      if (index < _nextIndex || index - _nextIndex > 120) await _stopDecoder();
      _checkOpen();
      if (_process == null) await _startDecoder(at: index);
      while (_nextIndex <= index) {
        final pixels = await _readPicture(keep: _nextIndex == index);
        _framesRead++;
        if (_nextIndex == index) {
          _last = MediaFrame(frameIndex: index, width: width, height: height, rgba: pixels!);
          frames[index] = _last!;
        }
        _nextIndex++;
      }
    }
    return frames;
  }

  Future<Uint8List?> _readPicture({required bool keep}) async {
    final reader = _bytes!;
    final process = _process!;
    final size = width * height * 4;
    final pixels = keep ? Uint8List(size) : null;
    var consumed = 0;
    try {
      while (consumed < size) {
        if (_offset == _chunk.length) {
          final available = await reader.moveNext().timeout(_tools.timeout);
          _checkOpen();
          if (!available) {
            final code = await process.exitCode;
            await _stderrDone;
            throw MediaProcessException(
              'Decoder ended before source frame $_nextIndex of "$_source".',
              exitCode: code,
              stderr: _stderr,
            );
          }
          _chunk = reader.current;
          _offset = 0;
        }
        final length = (size - consumed).clamp(0, _chunk.length - _offset);
        pixels?.setRange(consumed, consumed + length, _chunk, _offset);
        consumed += length;
        _offset += length;
      }
      return pixels;
    } on TimeoutException {
      await _stopDecoder();
      throw MediaProcessException('Decoding "$_source" timed out.', stderr: _stderr);
    }
  }

  /// Terminates and reaps the decoder. Calling repeatedly is harmless.
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    await _stopDecoder();
    await _pending;
    _last = null;
    _tools._sessions.remove(this);
  }

  void _checkOpen() {
    if (_cancelled) throw const MediaCancelledException();
    if (_closed) throw StateError('The frame session has been closed.');
  }

  Future<void> _cancel() {
    _cancelled = true;
    return close();
  }
}

/// Owned frame-session creation for native media tools.
extension FfmpegFrameSessions on FfmpegMediaTools {
  /// Opens one source reader; only its requested frames enter Dart memory.
  Future<FfmpegFrameSession> openFrameSession(
    Uri source, {
    required int width,
    required int height,
    String? decoder,
    Future<void>? whenCancelled,
  }) async {
    if (_closed) throw StateError('Media tools have been closed.');
    if (width <= 0 || height <= 0) throw ArgumentError('Frame dimensions must be positive.');
    if (decoder != null && (decoder.isEmpty || decoder.startsWith('-'))) {
      throw ArgumentError.value(decoder, 'decoder', 'must be a decoder name');
    }
    final path = FfmpegMediaTools._path('$source');
    final index = await _probeFrameIndex(path, whenCancelled: whenCancelled);
    return _openIndexedSession(path, width, height, index, decoder, whenCancelled);
  }

  FfmpegFrameSession _openIndexedSession(
    String path,
    int width,
    int height,
    _SourceFrameIndex index,
    String? decoder,
    Future<void>? whenCancelled,
  ) {
    if (_closed) throw StateError('Media tools have been closed.');
    final session = FfmpegFrameSession._(this, path, width, height, index, decoder);
    _sessions.add(session);
    if (whenCancelled != null) unawaited(whenCancelled.then((_) => session._cancel()));
    return session;
  }
}
