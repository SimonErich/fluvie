/// @docImport 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
/// @docImport 'package:fluvie/src/timing/schedule/composition_registrar.dart';
library;

import 'package:flutter/widgets.dart'
    show BuildContext, GlobalKey, KeyedSubtree, State, StatefulWidget, Widget;
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/runtime/local_schedule_resolver.dart';
import 'package:fluvie/src/animation/runtime/registrar_binding.dart';
import 'package:fluvie/src/animation/stagger/stagger_distributor.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/rendering/primitives/fade_box.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/timing/placement/window_resolver.dart';
import 'package:fluvie/src/timing/schedule/element_schedule.dart';
import 'package:fluvie/src/timing/schedule/resolved_schedule_scope.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';
import 'package:fluvie/src/timing/window_scope.dart';

/// The widget behind `.animate()`:
/// binds a list of [Animation]s to one element and renders it for the
/// current frame.
///
/// Per build it reads the frame ([FrameProvider], the only clock), the
/// nearest time scope, and the element's [ElementSchedule] — in the
/// consult order: an explicit [ResolvedScheduleScope] (nearest-wins), then
/// the enclosing [CompositionRegistrar] (how `Video` injects every nested
/// element's schedule by lookup), then a memoized local resolution — one
/// resolver code path behind all three. Under a still-collecting registrar
/// (the collect pass) it registers itself and renders the child hidden with its
/// layout slot held; the post-resolution rebuild injects the real spans.
///
/// A [WindowScope] around the subtree makes descendant relative times resolve
/// against [window] and lets nested registrations inherit it.
/// Animations carrying (or inheriting) a stagger distribute across a
/// multi-child [child] with per-child span offsets.
final class MotionTarget extends StatefulWidget {
  /// Animates [child] with [animations]; all other parameters mirror
  /// `.animate()`'s named arguments.
  const MotionTarget({
    required this.animations,
    required this.child,
    this.anchor,
    this.window,
    this.defaults,
    super.key,
  });

  /// The animations bound to this element, in declaration order.
  final List<Animation> animations;

  /// The element being animated.
  final Widget child;

  /// Names this element's timeline so other elements' triggers can reference
  /// it; collected into the composition plan by the enclosing `Video`.
  final Anchor? anchor;

  /// The element's alive-window within its scene, or `null` for the whole
  /// scene.
  final TimeRange? window;

  /// Element-level defaults merged over the inherited cascade,
  /// or `null` to inherit unchanged.
  final Defaults? defaults;

  @override
  State<MotionTarget> createState() => _MotionTargetState();
}

/// Holds the registrar binding (token + registrar) and the memoized
/// local schedule; resolution is pure, so the cache is a per-frame perf
/// shortcut, never a semantic.
final class _MotionTargetState extends State<MotionTarget> {
  final RegistrarBinding _binding = RegistrarBinding();
  final GlobalKey _subtreeKey = GlobalKey(debugLabel: 'MotionTarget child');
  ElementSchedule? _cachedSchedule;
  TimeScopeData? _cachedScope;

  @override
  void didUpdateWidget(MotionTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.animations, widget.animations) ||
        oldWidget.window != widget.window ||
        oldWidget.defaults != widget.defaults ||
        !identical(oldWidget.anchor, widget.anchor)) {
      _cachedSchedule = null;
      _cachedScope = null;
      // Post-resolution changes violate the determinism contract and throw;
      // during collect the stale token is rebuilt on the next build.
      _binding.didChangeTimingFields();
    }
  }

  @override
  void dispose() {
    _binding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = FrameProvider.of(context).frame;
    final scope = TimeScopeProvider.of(context);
    final lookup = _binding.lookup(
      context,
      animations: widget.animations,
      anchor: widget.anchor,
      window: widget.window,
      defaults: widget.defaults,
      childType: widget.child.runtimeType,
    );
    final schedule = switch (lookup) {
      ScheduleReady(:final schedule) => schedule,
      Standalone() => _localSchedule(scope),
      // Collect pass: hidden placeholder, layout slot held, no animation
      // math — the FadeBox primitive at 0 paints nothing.
      CollectPending() => null,
    };
    // Under a registrar the child lives behind a GlobalKey: wrapper chains
    // change shape between the collect and resolved passes (and on
    // window-boundary frames), and the key reparents nested registrations
    // instead of remounting them.
    final child = _binding.isBound
        ? KeyedSubtree(key: _subtreeKey, child: widget.child)
        : widget.child;
    if (schedule == null) {
      return WindowScope(
        window: widget.window,
        child: FadeBox(opacity: 0, child: child),
      );
    }
    if (schedule.spans.length != widget.animations.length) {
      throw FluvieTimingError(
        'The resolved schedule carries ${schedule.spans.length} spans for '
        '${widget.animations.length} animations on this element — spans and '
        'animations must align index by index. Was the injected schedule '
        'built from a different animations list?',
      );
    }
    return WindowScope(
      window: widget.window,
      child: buildStaggeredFrame(
        child: child,
        animations: widget.animations,
        schedule: schedule,
        elementScope: elementScopeFor(widget.window, scope),
        frame: frame,
      ),
    );
  }

  /// The local fallback of the schedule contract (the documented
  /// standalone mode), memoized until the scope or the widget's
  /// timing-relevant fields change.
  ElementSchedule _localSchedule(TimeScopeData scope) {
    final cached = _cachedSchedule;
    if (cached != null && scope == _cachedScope) return cached;
    try {
      final schedule = resolveLocalSchedule(
        animations: widget.animations,
        window: widget.window,
        sceneScope: scope,
        elementDefaults: widget.defaults,
      );
      _cachedSchedule = schedule;
      _cachedScope = scope;
      return schedule;
    } on FluvieTimingError catch (error) {
      if (_usesCompositionTriggers()) {
        throw FluvieTimingError(
          '${error.message} Cross-element and beat triggers resolve at the '
          'composition level — mount this element inside Video/Scene so the '
          'resolver can see the whole plan.',
          anchors: error.anchors,
        );
      }
      rethrow;
    }
  }

  /// Whether any animation waits on another element or a beat grid — the
  /// triggers local resolution can never satisfy.
  bool _usesCompositionTriggers() => widget.animations.any(
    (animation) => switch (animation.at) {
      AfterTrigger() || WhenStartsTrigger() || BeatTrigger() => true,
      _ => false,
    },
  );
}
