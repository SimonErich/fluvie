/// @docImport 'package:fluvie/src/rendering/runtime/live_player.dart';
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fluvie/src/rendering/runtime/live_playback_state.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';

export 'package:fluvie/src/rendering/runtime/live_playback_state.dart';

part 'live_playback_clock.dart';

/// A wall-clock face for the frame clock: maps elapsed time to frame indexes
/// so a composition plays live instead of being stepped by a capture loop.
///
/// The controller owns a [RenderController] (the same clock capture uses) and
/// republishes it through [frames]; a [LivePlayer] binds a `Ticker` to
/// [handleTick] and mounts the scope that delivers the frame to the tree.
/// Playback state and [rate] changes notify the controller's own listeners;
/// per-frame updates notify [frames] only, so a stage rebuilds per frame
/// without chrome rebuilding with it.
///
/// ```dart
/// final playback = LivePlaybackController(fps: video.fps);
/// LivePlayer(controller: playback, child: video);
/// playback.play();                    // free-run from the current frame
/// playback.hold(120);                 // land on frame 120 and freeze
/// await playback.playRange(120, 180); // play a segment, stop exactly at 180
/// ```
///
/// The controller never guesses an end: [totalFrames] is optional, and an
/// unbounded clock runs until told otherwise — which is what a live consumer
/// that paces content by input wants.
final class LivePlaybackController extends ChangeNotifier {
  /// Creates a paused clock at [initialFrame] that resolves elapsed time
  /// against [fps], scaled by [rate].
  ///
  /// [totalFrames] bounds playback: the last picture remains visible for its
  /// full interval before the clock pauses. `null` leaves it unbounded.
  LivePlaybackController({
    required this.fps,
    this.totalFrames,
    double rate = 1,
    int initialFrame = 0,
  }) : assert(fps > 0, 'fps must be > 0, got $fps'),
       assert(
         totalFrames == null || totalFrames > 0,
         'totalFrames must be > 0 when bounded, got $totalFrames',
       ),
       assert(rate > 0, 'rate must be > 0, got $rate'),
       _rate = rate,
       _positionFrames = initialFrame.toDouble(),
       _renderController = RenderController(initialFrame: initialFrame);

  /// Frames per second the clock resolves elapsed wall time against.
  final int fps;

  /// The bound of the clock, or `null` for an unbounded one. A bounded clock
  /// paints `totalFrames - 1` until the full `totalFrames / fps` duration ends.
  final int? totalFrames;

  final RenderController _renderController;
  LivePlaybackState _state = LivePlaybackState.paused;
  double _rate;

  // The play-segment bookkeeping: frames resolve as
  // `_baseFrame + (elapsed - _baseElapsed) × fps × rate`, and every seek,
  // play, or rate change rebases so the clock never jumps.
  double _baseFrame = 0;
  double _positionFrames;
  Duration _baseElapsed = Duration.zero;
  Duration _lastElapsed = Duration.zero;
  int? _rangeEnd;
  Completer<void>? _rangeCompleter;

  /// The frame clock this controller drives — the handle a
  /// `RenderControllerScope` republishes to the tree. Listen to it for
  /// per-frame notifications.
  ValueListenable<int> get frames => _renderController;

  /// The underlying [RenderController], for the [LivePlayer] to republish
  /// through the same scope capture uses. Drive playback through this
  /// controller's own surface, never by seeking the clock directly.
  @internal
  RenderController get renderController => _renderController;

  /// The current frame index.
  int get frame => _renderController.frame;

  /// Continuous transport time, including the final picture's full interval.
  Duration get position => Duration(
    microseconds: (_positionFrames / fps * Duration.microsecondsPerSecond).round(),
  );

  /// Whether natural playback reached the complete authored duration.
  ///
  /// Holding or seeking the final picture does not complete playback.
  bool get isComplete => totalFrames != null && _positionFrames >= totalFrames!;

  /// Whether the clock is advancing or frozen.
  LivePlaybackState get state => _state;

  /// The playback speed multiplier. Setting it while playing rebases the
  /// clock at the current frame, so the speed changes without a jump.
  double get rate => _rate;
  set rate(double value) {
    assert(value > 0, 'rate must be > 0, got $value');
    if (value == _rate) return;
    _rebase();
    _rate = value;
    notifyListeners();
  }

  /// Starts free-running playback from the current frame.
  ///
  /// A no-op while already playing, and on a bounded clock that is already
  /// at its complete duration. A held last picture can still play its interval.
  void play() {
    if (_state == LivePlaybackState.playing) return;
    if (isComplete) return;
    _state = LivePlaybackState.playing;
    _baseFrame = _positionFrames;
    _baseElapsed = Duration.zero;
    _lastElapsed = Duration.zero;
    notifyListeners();
  }

  /// Freezes the clock at the current frame. Pending [playRange] futures
  /// complete: the interruption is the new held state.
  void pause() {
    _rangeEnd = null;
    _completeRange();
    if (_state == LivePlaybackState.paused) return;
    _state = LivePlaybackState.paused;
    notifyListeners();
  }

  /// Jumps to [frame] exactly. A playing clock rebases and keeps playing
  /// from the target; a paused one just lands there.
  void seek(int frame) {
    assert(frame >= 0, 'frame must be >= 0, got $frame');
    _rangeEnd = null;
    _completeRange();
    _positionFrames = frame.toDouble();
    _renderController.seek(_paintFrame(frame));
    _rebase();
  }

  /// Lands on [frame] and freezes there — the held-state primitive: back
  /// navigation and jumps want a target state, not a reverse animation.
  void hold(int frame) {
    seek(frame);
    pause();
  }

  /// Plays the segment from [start] to [end] and stops exactly on [end].
  ///
  /// The returned future completes when the clock reaches [end] — or when
  /// the segment is interrupted by [pause], [seek], [hold], another range,
  /// or [dispose]; it never errors and never hangs.
  Future<void> playRange(int start, int end) {
    assert(start >= 0, 'start must be >= 0, got $start');
    assert(end >= start, 'the range must not be inverted, got $start..$end');
    seek(start);
    if (end == start) {
      pause();
      return Future<void>.value();
    }
    final completer = Completer<void>();
    _rangeCompleter = completer;
    _rangeEnd = end;
    _state = LivePlaybackState.playing;
    _baseFrame = start.toDouble();
    _baseElapsed = Duration.zero;
    _lastElapsed = Duration.zero;
    notifyListeners();
    return completer.future;
  }

  /// The ticker seam: a [LivePlayer] forwards its `Ticker` elapsed times
  /// here, and tests drive it directly for deterministic playback.
  ///
  /// Ignored while paused. [elapsed] is the ticker's total elapsed time
  /// since it started, monotonically non-decreasing between rebases. When
  /// it jumps backward, a fresh ticker took over (the player remounted);
  /// the clock rebases at the current frame and carries on — it never
  /// rewinds.
  void handleTick(Duration elapsed) {
    if (_handleTick(elapsed)) notifyListeners();
  }

  @override
  void dispose() {
    _completeRange();
    _renderController.dispose();
    super.dispose();
  }
}
