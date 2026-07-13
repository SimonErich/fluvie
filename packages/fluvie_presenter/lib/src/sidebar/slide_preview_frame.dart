import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show LivePlaybackController, LivePlayer, Video;
import 'package:fluvie_presenter/src/stepping/slide_plan.dart';
import 'package:fluvie_presenter/src/stepping/step_scope.dart';
import 'package:fluvie_presenter/src/stepping/stop.dart';
import 'package:fluvie_presenter/src/stepping/stop_state.dart';
import 'package:fluvie_presenter/src/stepping/stretched_scene.dart';

/// One slide rendered at a settled state on a held clock — the deterministic
/// still the sidebar previews, the overview grid, and the speaker's
/// next-state preview all share.
///
/// The frame holds at the latest entrance-settle of the steps it shows, so
/// every reveal is complete and nothing animates: same widget in, same
/// pixels out.
final class SlidePreviewFrame extends StatefulWidget {
  /// Renders [video]'s scene for [plan], settled at [step] (`null` shows the
  /// slide's final step).
  const SlidePreviewFrame({required this.video, required this.plan, this.step, super.key});

  /// The authored deck.
  final Video video;

  /// The compiled plan of the slide being shown.
  final SlidePlan plan;

  /// The step to settle at; `null` means the last one.
  final int? step;

  @override
  State<SlidePreviewFrame> createState() => _SlidePreviewFrameState();
}

final class _SlidePreviewFrameState extends State<SlidePreviewFrame> {
  late final int _shownStep = widget.step ?? widget.plan.stepCount - 1;

  late final int _settleFrame = () {
    var settle = 0;
    for (var k = 0; k <= _shownStep; k++) {
      final entrance = widget.plan.steps[k].entranceFrames;
      if (entrance > settle) settle = entrance;
    }
    return settle;
  }();

  late final LivePlaybackController _clock = LivePlaybackController(fps: widget.video.fps)
    ..hold(_settleFrame);

  late final Map<Stop, StopState> _states = () {
    final states = <Stop, StopState>{};
    for (var k = 1; k < widget.plan.stepCount; k++) {
      final step = widget.plan.steps[k];
      for (final stop in step.stops) {
        states[stop] = k <= _shownStep
            ? RevealedStop(baseFrame: _settleFrame, skipFrames: step.entranceFrames)
            : const HiddenStop();
      }
    }
    return states;
  }();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StepScope(
    states: _states,
    child: LivePlayer(
      controller: _clock,
      child: FittedBox(
        child: SizedBox(
          width: widget.video.width.toDouble(),
          height: widget.video.height.toDouble(),
          child: Video(
            width: widget.video.width,
            height: widget.video.height,
            fps: widget.video.fps,
            motionDefaults: widget.video.motionDefaults,
            scenes: [stretchSceneForSlide(widget.video.scenes[widget.plan.sceneIndex])],
          ),
        ),
      ),
    ),
  );
}
