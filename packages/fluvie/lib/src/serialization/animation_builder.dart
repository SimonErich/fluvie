// fluvie:large-file-ok: the single exhaustive spec-to-preset dispatch; each case is one delegation
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/core/edge.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/serialization/animation_spec.dart';
import 'package:fluvie/src/serialization/codecs/enum_codec.dart';
import 'package:fluvie/src/serialization/codecs/keyframe_codec.dart';
import 'package:fluvie/src/serialization/codecs/time_codec.dart';

/// Builds a real [Animation] from an [AnimationSpec].
///
/// The spec's `at` already carries resolved (canonical) anchors, so no anchor
/// table is needed here. Every preset in [knownAnimationPresets] and the raw
/// `from`/`to`/`fromTo` forms are handled.
Animation buildAnimation(AnimationSpec spec) {
  final at = spec.at ?? Trigger.auto;
  final delay = spec.delay ?? Time.zero;
  final args = spec.args;
  switch (spec.kind) {
    case 'fadeIn':
      return Animation.fadeIn(
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'fadeOut':
      return Animation.fadeOut(
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'slideIn':
      return Animation.slideIn(
        from: _edge(args['from']) ?? Edge.bottom,
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'slideOut':
      return Animation.slideOut(
        to: _edge(args['to']) ?? Edge.top,
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'slideFadeIn':
      return Animation.slideFadeIn(
        from: _edge(args['from']) ?? Edge.bottom,
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'slideFadeOut':
      return Animation.slideFadeOut(
        to: _edge(args['to']) ?? Edge.top,
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'pop':
      return Animation.pop(
        overshoot: _double(args['overshoot']) ?? 1.1,
        spring: spec.spring,
        duration: spec.duration,
        ease: spec.ease,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'scaleOut':
      return Animation.scaleOut(
        to: _double(args['to']) ?? 0.85,
        spring: spec.spring,
        duration: spec.duration,
        ease: spec.ease,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'scaleIn':
      return Animation.scaleIn(
        from: _double(args['from']) ?? 0.85,
        spring: spec.spring,
        duration: spec.duration,
        ease: spec.ease,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'blurIn':
      return Animation.blurIn(
        sigma: _double(args['sigma']) ?? 12,
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'blurOut':
      return Animation.blurOut(
        sigma: _double(args['sigma']) ?? 12,
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'grain':
      return Animation.grain(
        _double(args['amount']) ?? 0,
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'vignette':
      return Animation.vignette(
        _double(args['amount']) ?? 0,
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'spin':
      return Animation.spin(
        period: _timeOr(args['period'], const Time.seconds(4)),
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'drift':
      return Animation.drift(
        to: _edge(args['to']) ?? Edge.right,
        distance: _double(args['distance']) ?? 0.1,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'kenBurns':
      return Animation.kenBurns(
        zoom: _double(args['zoom']) ?? 1.15,
        pan: _edge(args['pan']) ?? Edge.left,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'from':
      return Animation.from(
        decodeKeyframe(args['from']),
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'to':
      return Animation.to(
        decodeKeyframe(args['to']),
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'fromTo':
      return Animation.fromTo(
        decodeKeyframe(args['from']),
        decodeKeyframe(args['to']),
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
  }
  // coverage:ignore-line unreachable AnimationSpec fromJson validates the kind before this dispatch
  throw FluvieSpecError('Unknown animation kind "${spec.kind}"');
}

Edge? _edge(Object? raw) => raw == null ? null : decodeEnum(Edge.values, raw, 'edge');

double? _double(Object? raw) => raw is num ? raw.toDouble() : null;

Time _timeOr(Object? raw, Time fallback) => raw == null ? fallback : decodeTime(raw);
