part of 'video_preview.dart';

extension _VideoPreviewControls on _VideoPreviewState {
  Widget _controls() => ValueListenableBuilder<int>(
    valueListenable: _controller.frames,
    builder: (context, frame, _) => Row(
      children: [
        IconButton(
          tooltip: _controller.state == LivePlaybackState.playing ? 'Pause' : 'Play',
          color: Colors.white,
          onPressed: !_ready ? null : _togglePlayback,
          icon: Icon(
            _controller.state == LivePlaybackState.playing ? Icons.pause : Icons.play_arrow,
          ),
        ),
        if (widget.audio != null)
          IconButton(
            tooltip: _sound ? 'Mute' : 'Enable sound',
            color: Colors.white,
            onPressed: _toggleSound,
            icon: Icon(_sound ? Icons.volume_up : Icons.volume_off),
          ),
        Expanded(
          child: Slider(
            value: frame.clamp(0, _video.totalFrames - 1).toDouble(),
            max: (_video.totalFrames - 1).toDouble(),
            onChanged: !_ready ? null : (value) => _controller.seek(value.round()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text(
            '${(frame / _video.fps).toStringAsFixed(1)} / ${(_video.totalFrames / _video.fps).toStringAsFixed(1)}s',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}
