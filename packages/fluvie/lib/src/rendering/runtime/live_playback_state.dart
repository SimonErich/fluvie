/// @docImport 'package:fluvie/src/rendering/runtime/live_playback_controller.dart';
library;

/// Whether a [LivePlaybackController] is advancing its frame clock.
enum LivePlaybackState {
  /// The clock is frozen at the current frame; ticks are ignored.
  paused,

  /// The clock maps elapsed wall time to frames as ticks arrive.
  playing,
}
