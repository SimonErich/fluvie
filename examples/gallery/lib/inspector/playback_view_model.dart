import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/inspector/providers.dart';

/// What the playback bar binds to: the current frame, the scrub range, and
/// whether the preview is playing and at what rate.
final class PlaybackState {
  /// Creates a snapshot of the playback position.
  const PlaybackState({
    required this.frame,
    required this.totalFrames,
    this.isPlaying = false,
    this.playFps = 30,
  });

  /// The frame the preview currently shows.
  final int frame;

  /// The selected lesson's total frame count; the scrubber range is
  /// `0..totalFrames - 1`.
  final int totalFrames;

  /// Whether the preview is currently playing.
  final bool isPlaying;

  /// The playback rate in frames per second.
  final int playFps;
}

/// Owns the preview's [RenderController]: rebuilding for each
/// selected lesson, positioned at frame 0 so play runs from the start,
/// disposed with the provider.
///
/// [seek] is the single write path — it clamps to the playable range, drives
/// the controller (which the preview's `RenderControllerScope` republishes as
/// the frame clock), and mirrors the position into [PlaybackState] for the
/// scrubber. [play] and [pause] start/stop a periodic timer that advances
/// frames at [PlaybackState.playFps]. [setPlayFps] changes the rate and
/// restarts the timer if already playing.
final class PlaybackViewModel extends Notifier<PlaybackState> {
  late RenderController _controller;
  Timer? _playTimer;

  /// The frame clock the preview pane mounts; owned and disposed here.
  RenderController get controller => _controller;

  @override
  PlaybackState build() {
    _playTimer?.cancel();
    _playTimer = null;
    final video = ref.watch(selectedLessonProvider).video();
    // Each lesson starts at frame 0 so pressing play runs from the beginning.
    _controller = RenderController();
    ref.onDispose(() {
      _playTimer?.cancel();
      _controller.dispose();
    });
    return PlaybackState(frame: 0, totalFrames: video.totalFrames);
  }

  /// Jumps the preview to [frame], clamped to `0..totalFrames - 1`.
  void seek(int frame) {
    final clamped = frame.clamp(0, state.totalFrames - 1);
    _controller.seek(clamped);
    state = PlaybackState(
      frame: clamped,
      totalFrames: state.totalFrames,
      isPlaying: state.isPlaying,
      playFps: state.playFps,
    );
  }

  /// Starts playing from the current frame, looping at the end.
  void play() {
    if (state.isPlaying) return;
    state = PlaybackState(
      frame: state.frame,
      totalFrames: state.totalFrames,
      isPlaying: true,
      playFps: state.playFps,
    );
    _startTimer();
  }

  /// Pauses playback at the current frame.
  void pause() {
    _playTimer?.cancel();
    _playTimer = null;
    state = PlaybackState(
      frame: state.frame,
      totalFrames: state.totalFrames,
      playFps: state.playFps,
    );
  }

  /// Changes the playback rate to [fps]; restarts the timer if already playing.
  void setPlayFps(int fps) {
    final wasPlaying = state.isPlaying;
    if (wasPlaying) {
      _playTimer?.cancel();
      _playTimer = null;
    }
    state = PlaybackState(
      frame: state.frame,
      totalFrames: state.totalFrames,
      isPlaying: wasPlaying,
      playFps: fps,
    );
    if (wasPlaying) _startTimer();
  }

  void _startTimer() {
    _playTimer = Timer.periodic(
      Duration(milliseconds: 1000 ~/ state.playFps),
      (_) {
        final next = state.frame + 1;
        seek(next >= state.totalFrames ? 0 : next);
      },
    );
  }
}

/// The playback view model and its state.
final playbackViewModelProvider = NotifierProvider<PlaybackViewModel, PlaybackState>(
  PlaybackViewModel.new,
);
