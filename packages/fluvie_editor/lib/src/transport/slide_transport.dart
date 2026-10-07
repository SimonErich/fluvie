import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:fluvie/fluvie.dart' show LivePlaybackController, LivePlaybackState;
import 'package:fluvie_editor/src/transport/frame_range.dart';

/// The editor's shared playhead: one playback clock for the active slide,
/// driven by the timeline and mounted by the canvas — a single source of
/// truth, so the ruler and the stage can never disagree on the frame.
///
/// The transport wraps an unbounded [LivePlaybackController] and enforces
/// the slide [length] itself, so a retime updates the bound in place
/// instead of recreating the clock (the playhead survives edits). Slide
/// switches do the opposite: the owner disposes this transport and creates
/// a fresh one for the incoming slide.
///
/// Listeners hear playback, loop, and length changes; per-frame updates go
/// through [frames] only, mirroring the controller's own split.
final class SlideTransport extends ChangeNotifier {
  /// Creates a paused transport over a slide of [length] frames at [fps],
  /// holding [initialFrame] (clamped to the slide).
  SlideTransport({required this.fps, required int length, int initialFrame = 0})
    : assert(length >= 0, 'length must be >= 0, got $length'),
      _length = length,
      _controller = LivePlaybackController(
        fps: fps,
        initialFrame: initialFrame.clamp(0, math.max(0, length)),
      ) {
    _controller.addListener(notifyListeners);
  }

  /// Frames per second the clock resolves elapsed wall time against.
  final int fps;

  final LivePlaybackController _controller;
  int _length;
  FrameRange? _loop;
  int _epoch = 0;
  bool _disposed = false;

  /// The clock a `LivePlayer` mounts to put this transport's frame on
  /// stage. Drive playback through the transport, never through the
  /// controller directly — the transport owns the slide bound and the loop.
  LivePlaybackController get controller => _controller;

  /// The per-frame listenable (the same handle the stage rebuilds from).
  ValueListenable<int> get frames => _controller.frames;

  /// The current slide-relative frame.
  int get frame => _controller.frame;

  /// Whether the clock is advancing.
  bool get isPlaying => _controller.state == LivePlaybackState.playing;

  /// The armed loop range, or null when playback runs the whole slide.
  FrameRange? get loop => _loop;

  /// The slide's length in frames — where playback stops. Updating it
  /// re-clamps the playhead and the loop, and re-bounds a running play.
  int get length => _length;
  set length(int value) {
    assert(value >= 0, 'length must be >= 0, got $value');
    if (value == _length) return;
    _length = value;
    _loop = _clampedLoop(_loop);
    _epoch++;
    if (isPlaying) {
      final from = math.min(frame, value);
      final loop = _loop;
      if (loop != null && loop.contains(from)) {
        unawaited(_run(from, loop.end));
      } else {
        unawaited(_run(from, math.max(from, value)));
      }
    } else if (frame > value) {
      _controller.hold(value);
    }
    notifyListeners();
  }

  /// Lands exactly on [frame] (clamped to the slide) and freezes there —
  /// the scrub primitive: a scrub wants a held state, not a moving clock.
  /// An armed loop stays armed for the next [play].
  void seek(int frame) {
    _epoch++;
    _controller.hold(frame.clamp(0, _length));
  }

  /// Starts playback from the playhead: to the end of the armed [loop]
  /// (snapping into its range first when the playhead sits outside), or to
  /// the end of the slide — restarting from frame zero when the playhead
  /// is already there. A no-op while playing.
  void play() {
    if (isPlaying) return;
    final loop = _loop;
    if (loop != null) {
      unawaited(_run(loop.contains(frame) ? frame : loop.start, loop.end));
    } else {
      unawaited(_run(frame >= _length ? 0 : frame, _length));
    }
  }

  /// Freezes the clock at the current frame. An armed loop stays armed.
  void pause() {
    _epoch++;
    _controller.pause();
  }

  /// [pause] while playing, [play] while paused.
  void toggle() => isPlaying ? pause() : play();

  /// Seeks to [frame] and plays from there ([seek] then [play], so an
  /// armed loop confines the run the same way).
  void playFrom(int frame) {
    seek(frame);
    play();
  }

  /// Plays forward from the playhead and stops exactly on [end] (clamped
  /// to the slide) — the step primitive. A target at or before the
  /// playhead just lands there. The loop never wraps a stepped run.
  ///
  /// The future completes when the run lands or is interrupted; it never
  /// errors and never hangs.
  Future<void> playTo(int end) {
    final target = end.clamp(0, _length);
    if (target <= frame) {
      seek(target);
      return Future<void>.value();
    }
    return _run(frame, target, rearm: false);
  }

  /// Arms, retargets, or clears the loop (clamped to the slide; a range
  /// entirely beyond it clears). A running play re-confines immediately:
  /// into the new range, or on to the slide end when [range] is null.
  void setLoop(FrameRange? range) {
    final next = _clampedLoop(range);
    if (next == _loop) return;
    _loop = next;
    _epoch++;
    if (isPlaying) {
      if (next != null) {
        unawaited(_run(next.contains(frame) ? frame : next.start, next.end));
      } else {
        unawaited(_run(frame, math.max(frame, _length)));
      }
    }
    notifyListeners();
  }

  FrameRange? _clampedLoop(FrameRange? range) {
    if (range == null || range.start >= _length) return null;
    return range.end <= _length ? range : FrameRange(range.start, _length);
  }

  /// Runs one segment. The pause first stops the player's ticker, so the
  /// restarted ticker's elapsed time matches the fresh range base; the
  /// epoch invalidates the completion of any run this one interrupts.
  Future<void> _run(int start, int end, {bool rearm = true}) {
    final epoch = ++_epoch;
    _controller.pause();
    return _controller.playRange(start, end).then((_) {
      if (_disposed || epoch != _epoch || !rearm) return;
      final loop = _loop;
      if (loop == null || _controller.frame != loop.end) return;
      unawaited(_run(loop.start, loop.end));
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _controller
      ..removeListener(notifyListeners)
      ..dispose();
    super.dispose();
  }
}
