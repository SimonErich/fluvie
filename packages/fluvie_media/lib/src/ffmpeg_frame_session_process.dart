part of 'ffmpeg_media_tools.dart';

extension _FrameSessionProcess on FfmpegFrameSession {
  Future<void> _startDecoder({int at = 0, bool seek = true}) async {
    final key = seek ? _seekKey(at) : 0;
    _nextIndex = key;
    _chunk = const [];
    _offset = 0;
    _stderr = '';
    final firstTime = Completer<int?>();
    var diagnostic = '';
    final process = await _tools._startProcess(_tools.ffmpegPath, [
      '-v',
      if (key > 0) 'info' else 'error',
      '-nostdin',
      ...FfmpegMediaTools._localInputProtocols,
      if (key > 0) ...[
        '-copyts',
        '-ss',
        ((_index.timesUs[key] - _index.seekOriginUs) / 1000000).toStringAsFixed(6),
      ],
      if (_decoder != null) ...['-c:v', _decoder],
      '-i',
      _source,
      '-vf',
      '${key > 0 ? 'showinfo,' : ''}scale=$width:$height',
      '-fps_mode',
      'passthrough',
      '-f',
      'rawvideo',
      '-pix_fmt',
      'rgba',
      'pipe:1',
    ]);
    if (_closed) {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
      _checkOpen();
    }
    _process = process;
    _tools._processes.add(process);
    _starts++;
    _bytes = StreamIterator(process.stdout);
    _stderrDone = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach((text) {
          _stderr = FfmpegMediaTools._tail('$_stderr$text');
          if (key > 0 && !firstTime.isCompleted) {
            diagnostic = FfmpegMediaTools._tail('$diagnostic$text');
            final match = RegExp(
              r'\bn:\s*0\s+pts:\s*-?\d+\s+pts_time:([\d.eE+-]+)\s',
            ).firstMatch(diagnostic);
            final time = match == null ? null : _secondsUs(match.group(1));
            if (time != null) firstTime.complete(time);
          }
        })
        .whenComplete(() {
          if (!firstTime.isCompleted) firstTime.complete(null);
        });
    if (key > 0) {
      final int? observed;
      try {
        observed = await firstTime.future.timeout(_tools.timeout);
      } on TimeoutException {
        await _stopDecoder();
        _checkOpen();
        throw MediaProcessException('Seeking "$_source" timed out.');
      }
      _checkOpen();
      if (observed == null || (observed - _index.timesUs[key]).abs() > 1) {
        // Unusual demuxers can seek to a different picture. Decode from the
        // origin rather than assigning an incorrect source ordinal to pixels.
        await _stopDecoder();
        await _startDecoder(at: at, seek: false);
      }
    }
  }

  int _seekKey(int at) {
    if (at <= 30) return 0;
    final keys = _index.keyFrames;
    var low = 0;
    var high = keys.length;
    while (low < high) {
      final middle = low + ((high - low) ~/ 2);
      if (keys[middle] <= at) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    final selected = low == 0 ? 0 : keys[low - 1];
    // A duplicated PTS cannot prove which ordinal the decoder started at.
    final time = _index.timesUs[selected];
    if ((selected > 0 && _index.timesUs[selected - 1] == time) ||
        (selected + 1 < _index.timesUs.length && _index.timesUs[selected + 1] == time)) {
      return 0;
    }
    return selected;
  }

  Future<void> _stopDecoder() async {
    final process = _process;
    if (process == null) return;
    _process = null;
    process.kill(ProcessSignal.sigkill);
    await _bytes?.cancel();
    await process.exitCode;
    await _stderrDone;
    _tools._processes.remove(process);
    _bytes = null;
    _chunk = const [];
    _offset = 0;
    _nextIndex = 0;
  }
}
