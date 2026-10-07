part of 'slide_view.dart';

/// One mounted slide: its stretched composition, its clock, and its stop
/// states — everything a stage needs to render, kept so an outgoing slide
/// can hold during a blend.
final class _MountedSlide {
  _MountedSlide({required this.video, required this.clock, required this.states});

  final Video video;
  final LivePlaybackController clock;
  final Map<Stop, StopState> states;

  /// Anchors the stage subtree so it reparents (not remounts) when a blend
  /// starts or settles — a remounted player restarts its ticker, and the
  /// slide would replay its entrance.
  final GlobalKey stageKey = GlobalKey();

  void dispose() => clock.dispose();
}
