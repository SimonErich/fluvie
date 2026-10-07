// fluvie:large-file-ok: the single exhaustive spec-to-preset dispatch; each case is one delegation
import 'dart:ui' show Path;

import 'package:flutter/animation.dart' show Curve;
import 'package:flutter/painting.dart' show Alignment, Color;
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/audio_band.dart';
import 'package:fluvie/src/core/edge.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/svg_path.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_order.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/core/wipe_shape.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/animation_spec.dart';
import 'package:fluvie/src/serialization/codecs/alignment_codec.dart';
import 'package:fluvie/src/serialization/codecs/color_codec.dart';
import 'package:fluvie/src/serialization/codecs/curve_codec.dart';
import 'package:fluvie/src/serialization/codecs/enum_codec.dart';
import 'package:fluvie/src/serialization/codecs/keyframe_codec.dart';
import 'package:fluvie/src/serialization/codecs/particles_codec.dart';
import 'package:fluvie/src/serialization/codecs/time_codec.dart';

part 'animation_builder_args.dart';
part 'animation_builder_keyframes.dart';
part 'animation_builder_wave2.dart';

/// Builds a real [Animation] from an [AnimationSpec].
///
/// The spec's `at` already carries resolved (canonical) anchors; [anchors] is
/// the document's shared table, needed only by the reactive presets whose
/// `track` argument names an `Audio.track` timeline. Every preset in
/// [knownAnimationPresets], the multi-stop `keyframes` form, and the raw
/// `from`/`to`/`fromTo` forms are handled.
Animation buildAnimation(AnimationSpec spec, AnchorTable anchors) {
  final animation = _buildAnimation(spec, anchors);
  final ease = spec.ease;
  return ease == null || identical(animation.ease, ease) ? animation : animation.withEase(ease);
}

Animation _buildAnimation(AnimationSpec spec, AnchorTable anchors) {
  final at = spec.at ?? Trigger.auto;
  final delay = spec.delay ?? Time.zero;
  final args = spec.args;
  switch (spec.kind) {
    case 'keyframes':
      return _keyframesAnimation(spec);
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
    case 'maskWipeIn':
      return Animation.maskWipeIn(
        shape: _wipeShape(args['shape']),
        origin: _alignment(args['origin']),
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'maskWipeOut':
      return Animation.maskWipeOut(
        shape: _wipeShape(args['shape']),
        origin: _alignment(args['origin']),
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'glitchIn':
      return Animation.glitchIn(
        from: _edge(args['from']) ?? Edge.left,
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'glitchOut':
      return Animation.glitchOut(
        to: _edge(args['to']) ?? Edge.right,
        duration: spec.duration,
        ease: spec.ease,
        spring: spec.spring,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'float':
      return Animation.float(
        amplitude: _double(args['amplitude']) ?? 0.04,
        period: _timeOr(args['period'], const Time.seconds(2.5)),
        seed: args['seed'] is String ? args['seed']! as String : null,
        delay: delay,
        at: at,
        stagger: spec.stagger,
        repeat: spec.repeat,
        label: spec.label,
      );
    case 'pulse':
      return Animation.pulse(
        on: args['on'] == null
            ? null
            : decodeEnum(AudioBand.values, args['on'], 'band', path: const ['on']),
        gain: _double(args['gain']) ?? 1.0,
        track: _trackAnchor(args['track'], anchors),
        min: _double(args['min']) ?? 0.97,
        max: _double(args['max']) ?? 1.03,
        period: _timeOr(args['period'], const Time.seconds(1.2)),
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
  return _wave2Animation(spec, anchors);
}

Edge? _edge(Object? raw) => raw == null ? null : decodeEnum(Edge.values, raw, 'edge');

WipeShape _wipeShape(Object? raw) =>
    raw == null ? WipeShape.circle : decodeEnum(WipeShape.values, raw, 'shape');

Alignment _alignment(Object? raw) =>
    raw == null ? Alignment.center : decodeAlignment(raw, path: const ['origin']);

double? _double(Object? raw) => raw is num ? raw.toDouble() : null;

Time _timeOr(Object? raw, Time fallback) => raw == null ? fallback : decodeTime(raw);
