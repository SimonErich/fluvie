part of 'video_preview.dart';

extension _PreviewAudioPlayback on _VideoPreviewState {
  void _frameChanged() {
    if (widget.audio == null || !_sound) return;
    _audioPending = true;
    if (!_syncingAudio) unawaited(_synchronizeAudio());
  }

  Future<void> _synchronizeAudio() async {
    _syncingAudio = true;
    try {
      while (mounted && _audioPending) {
        _audioPending = false;
        await widget.audio?.synchronize(
          position: _controller.position,
          playing: _sound && _ready && _controller.state == LivePlaybackState.playing,
          rate: _controller.rate,
        );
      }
    } on Object catch (error) {
      _reportError(error);
    } finally {
      _syncingAudio = false;
    }
  }

  Future<void> _toggleSound() async {
    try {
      await widget.audio?.activate();
      if (!mounted) return;
      _audioActivated = true;
      _setSound(!_sound);
      _audioPending = true;
      unawaited(_synchronizeAudio());
    } on Object catch (error) {
      _reportError(error);
    }
  }

  Future<void> _togglePlayback() async {
    if (_controller.state == LivePlaybackState.playing) {
      _controller.pause();
      return;
    }
    try {
      // Browser audio activation begins in the original user gesture, before
      // any awaited network preparation. Visual autoplay remains muted.
      if (widget.audio != null && !_audioActivated) {
        await widget.audio!.activate();
        if (!mounted) return;
        _audioActivated = true;
        _sound = true;
      }
      if (_controller.isComplete) _controller.seek(0);
      _controller.play();
    } on Object catch (error) {
      _reportError(error);
    }
  }
}
