part of 'live_playback_controller.dart';

extension _LivePlaybackClock on LivePlaybackController {
  /// The frame the current run must stop on: the pending range end, the
  /// bound of the clock, or `null` for a free run on an unbounded clock.
  int? get _stopFrame {
    final last = totalFrames;
    final end = _rangeEnd;
    if (end == null) return last;
    return last == null ? end : (end < last ? end : last);
  }

  int? get _lastFrame {
    final total = totalFrames;
    return total == null ? null : total - 1;
  }

  int _paintFrame(int frame) => _lastFrame == null || frame <= _lastFrame! ? frame : _lastFrame!;

  /// Rebases the elapsed→frame mapping at the current frame so the next tick
  /// continues from here — the no-jump invariant behind seek and rate.
  void _rebase() {
    _baseFrame = _positionFrames;
    _baseElapsed = _lastElapsed;
  }

  void _completeRange() {
    final completer = _rangeCompleter;
    _rangeCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  bool _handleTick(Duration elapsed) {
    if (_state == LivePlaybackState.paused) return false;
    if (elapsed < _lastElapsed) {
      _baseFrame = _positionFrames;
      _baseElapsed = elapsed;
    }
    _lastElapsed = elapsed;
    final seconds = (elapsed - _baseElapsed).inMicroseconds / Duration.microsecondsPerSecond;
    var target = _baseFrame + seconds * fps * _rate;
    final stopAt = _stopFrame;
    if (stopAt != null && target >= stopAt) {
      target = stopAt.toDouble();
      _positionFrames = target;
      _renderController.seek(_paintFrame(target.floor()));
      _rangeEnd = null;
      _completeRange();
      _state = LivePlaybackState.paused;
      return true;
    }
    _positionFrames = target;
    _renderController.seek(_paintFrame((target + 1e-9).floor()));
    return false;
  }
}
