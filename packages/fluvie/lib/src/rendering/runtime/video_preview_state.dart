part of 'video_preview.dart';

class _VideoPreviewState extends State<VideoPreview> {
  late Video _video;
  late LivePlaybackController _controller;
  bool _ownsController = false;
  bool _ready = false;
  bool _resumeWhenReady = false;
  bool _sound = false;
  bool _audioActivated = false;
  bool _syncingAudio = false;
  bool _audioPending = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _video = widget.video ?? widget.builder!();
    _resumeWhenReady = widget.autoplay;
    _bindController();
  }

  void _bindController({int initialFrame = 0}) {
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        LivePlaybackController(
          fps: _video.fps,
          totalFrames: _video.totalFrames,
          initialFrame: initialFrame.clamp(0, _video.totalFrames - 1),
        );
    if (_controller.fps != _video.fps) {
      throw ArgumentError(
        'VideoPreview controller fps (${_controller.fps}) must match Video fps (${_video.fps}).',
      );
    }
    _controller.addListener(_playbackChanged);
    _controller.frames.addListener(_frameChanged);
  }

  void _unbindController() {
    _controller.removeListener(_playbackChanged);
    _controller.frames.removeListener(_frameChanged);
    if (_ownsController) _controller.dispose();
  }

  @override
  void didUpdateWidget(VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.audio, widget.audio)) {
      unawaited(oldWidget.audio?.synchronize(position: Duration.zero, playing: false, rate: 1));
      _audioActivated = false;
      _sound = false;
    }
    if (oldWidget.video != widget.video ||
        oldWidget.builder != widget.builder ||
        oldWidget.controller != widget.controller) {
      _replaceVideo(widget.video ?? widget.builder!());
    }
  }

  void _replaceVideo(Video video) {
    final seconds = _controller.frame / _controller.fps;
    if (_ready) _resumeWhenReady = _controller.state == LivePlaybackState.playing;
    _ready = false;
    _controller.pause();
    _unbindController();
    _video = video;
    _bindController(initialFrame: (seconds * video.fps).floor());
    _ready = false;
    _error = null;
  }

  @override
  void reassemble() {
    super.reassemble();
    final builder = widget.builder;
    if (builder != null) setState(() => _replaceVideo(builder()));
  }

  void _playbackChanged() {
    if (!mounted) return;
    if (widget.loop &&
        _ready &&
        _controller.frame == _video.totalFrames - 1 &&
        _controller.state == LivePlaybackState.paused) {
      _controller
        ..seek(0)
        ..play();
    }
    setState(() {});
    if (_ready) _resumeWhenReady = _controller.state == LivePlaybackState.playing;
    _frameChanged();
  }

  void _setSound(bool sound) => setState(() => _sound = sound);

  void _reportError(Object error) {
    if (!mounted) return;
    setState(() => _error = error);
    widget.onError?.call(error);
  }

  @override
  void dispose() {
    final audio = widget.audio;
    if (audio != null) {
      unawaited(audio.synchronize(position: Duration.zero, playing: false, rate: 1));
    }
    _unbindController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvas = LivePlayer(
      controller: _controller,
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: fluvieDefaultFontFamily),
        child: PreviewMediaScope(
          composition: _video,
          frames: _controller.frames,
          resolver: widget.resolver,
          clipDecoder: widget.clipDecoder,
          assetBundle: widget.assetBundle,
          maxClipEdge: widget.maxClipEdge,
          onError: _reportError,
          onReady: (resolver) {
            if (!mounted) return;
            setState(() => _ready = true);
            widget.onReady?.call(resolver);
            if (_resumeWhenReady) _controller.play();
          },
        ),
      ),
    );
    if (widget.surfaceBuilder != null) {
      return widget.surfaceBuilder!(context, canvas, _ready, _error);
    }
    return Material(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: FittedBox(
                    child: SizedBox(
                      width: _video.width.toDouble(),
                      height: _video.height.toDouble(),
                      child: canvas,
                    ),
                  ),
                ),
                if (!_ready && _error == null) const CircularProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '$_error',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
          if (widget.showControls) _controls(),
        ],
      ),
    );
  }
}
