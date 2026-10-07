part of 'animate_section.dart';

extension _AnimateSectionCommands on AnimateSection {
  /// A duration edit follows the same law as a timeline trim: a keyframes
  /// form with authored positions keeps its stops proportional, and when
  /// the new span cannot hold them the edit stops.
  void _dispatchDuration(TimelineBarBinding binding, Map<String, Object?> json, double next) {
    final duration = next.round();
    List<int>? positions;
    if (binding.stopFrames != null && json.containsKey('positions')) {
      positions = rescaledStopFrames(
        binding.stopFrames!,
        from: binding.durationFrames,
        to: duration,
      );
      if (positions == null) return;
    }
    onCommand(
      SetAnimationDurationCommand(
        id: elementId,
        index: binding.index,
        durationFrames: duration,
        positionFrames: positions,
      ),
    );
  }

  void _dispatchAdd(String? next) {
    if (next == null || isAnimatePresetHeading(next)) return;
    onCommand(
      AddAnimationCommand(
        id: elementId,
        animation: next == 'keyframes'
            ? const {
                'keyframes': [<String, Object?>{}, <String, Object?>{}],
              }
            : {'preset': next},
      ),
    );
  }
}
