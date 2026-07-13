import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart'
    show LivePlaybackController, LivePlayer, TimeScope, Transition, TransitionKind, Video;
import 'package:fluvie_presenter/src/controller/navigation_kind.dart';
import 'package:fluvie_presenter/src/controller/presentation_controller.dart';
import 'package:fluvie_presenter/src/controller/presentation_position.dart';
import 'package:fluvie_presenter/src/controller/presentation_state.dart';
import 'package:fluvie_presenter/src/stepping/slide_plan.dart';
import 'package:fluvie_presenter/src/stepping/slide_transition_blend.dart';
import 'package:fluvie_presenter/src/stepping/step_scope.dart';
import 'package:fluvie_presenter/src/stepping/stop.dart';
import 'package:fluvie_presenter/src/stepping/stop_state.dart';
import 'package:fluvie_presenter/src/stepping/stretched_scene.dart';

part 'slide_view_state.dart';

/// Renders the current slide at the current step and follows the
/// presentation controller: forward advances reveal steps with their
/// authored entrances, backward moves and jumps land on held states, and
/// slide changes play the authored boundary transition (or cut, when
/// [playTransitions] is off).
///
/// Each slide mounts as its own single-scene composition on a free-running
/// clock, stretched to the slide horizon — which is why ambient loops keep
/// running while a step holds. The view reads positions from
/// `presentationControllerProvider` and the compiled deck from
/// `slidePlansProvider`.
final class SlideView extends ConsumerStatefulWidget {
  /// Presents [video] slide by slide.
  const SlideView({required this.video, this.playTransitions = true, this.clockFactory, super.key});

  /// The authored deck.
  final Video video;

  /// Whether slide changes play the authored transition; `false` always
  /// cuts.
  final bool playTransitions;

  /// A test seam: builds the clock for each slide mount. The view owns the
  /// returned clocks either way; the default is a free-running clock.
  final LivePlaybackController Function(int fps)? clockFactory;

  @override
  ConsumerState<SlideView> createState() => _SlideViewState();
}

/// The presenter-side resolution scope for boundary-transition durations:
/// only [fps] matters — transitions must be absolute, so nothing resolves
/// against a window here.
final class _PresenterTimeScope implements TimeScope {
  const _PresenterTimeScope(this.fps);

  @override
  final int fps;

  @override
  int get startFrame => 0;

  @override
  int get durationFrames => 0;

  @override
  TimeScope? get parent => null;
}
