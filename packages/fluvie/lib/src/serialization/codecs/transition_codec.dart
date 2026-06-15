import 'package:flutter/painting.dart' show Alignment;
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/edge.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/serialization/codecs/alignment_codec.dart';
import 'package:fluvie/src/serialization/codecs/curve_codec.dart';
import 'package:fluvie/src/serialization/codecs/enum_codec.dart';
import 'package:fluvie/src/serialization/codecs/time_codec.dart';

/// The JSON form of a [Transition]: an object tagged by `kind`, carrying the
/// canonical fields for that kind (a cut carries only its kind).
Map<String, Object?> encodeTransition(Transition transition, {List<String> path = const []}) {
  String time() => encodeTime(transition.duration, path: path);
  String ease() => encodeCurve(transition.ease, path: path);
  return switch (transition.kind) {
    TransitionKind.cut => {'kind': 'cut'},
    TransitionKind.crossFade => {
      'kind': 'crossFade',
      'duration': time(),
      'overlap': transition.overlap,
      'ease': ease(),
    },
    TransitionKind.wipe => {
      'kind': 'wipe',
      'duration': time(),
      'direction': encodeEnum(transition.direction!),
      'overlap': transition.overlap,
      'ease': ease(),
    },
    TransitionKind.zoom => {
      'kind': 'zoom',
      'duration': time(),
      'into': encodeAlignment(transition.into!),
      'overlap': transition.overlap,
      'ease': ease(),
    },
    TransitionKind.slide => {
      'kind': 'slide',
      'duration': time(),
      'from': encodeEnum(transition.from!),
      'overlap': transition.overlap,
      'ease': ease(),
    },
  };
}

/// Reads a [Transition] from an object in [raw].
///
/// Throws a [FluvieSpecError] (located at [path]) for a non-object, an unknown
/// kind, or a timed kind missing its `duration`.
Transition decodeTransition(Object? raw, {List<String> path = const []}) {
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a transition object', path: path);
  }
  final kind = decodeEnum(
    TransitionKind.values,
    raw['kind'],
    'transition kind',
    path: [...path, 'kind'],
  );
  final overlapRaw = raw['overlap'];
  final overlap = overlapRaw is! bool || overlapRaw;
  final ease = raw['ease'] == null
      ? Ease.linear
      : decodeCurve(raw['ease'], path: [...path, 'ease']);
  Time duration() => _duration(raw, path);
  return switch (kind) {
    TransitionKind.cut => const Transition.cut(),
    TransitionKind.crossFade => Transition.crossFade(duration(), overlap: overlap, ease: ease),
    TransitionKind.wipe => Transition.wipe(
      duration(),
      direction: _edge(raw['direction'], Edge.right, [...path, 'direction']),
      overlap: overlap,
      ease: ease,
    ),
    TransitionKind.zoom => Transition.zoom(
      duration(),
      into: _alignment(raw['into'], Alignment.center, [...path, 'into']),
      overlap: overlap,
      ease: ease,
    ),
    TransitionKind.slide => Transition.slide(
      duration(),
      from: _edge(raw['from'], Edge.right, [...path, 'from']),
      overlap: overlap,
      ease: ease,
    ),
  };
}

Time _duration(Map<String, Object?> raw, List<String> path) {
  final value = raw['duration'];
  if (value == null) {
    throw FluvieSpecError('This transition needs a "duration"', path: [...path, 'duration']);
  }
  return decodeTime(value, path: [...path, 'duration']);
}

Edge _edge(Object? raw, Edge fallback, List<String> path) =>
    raw == null ? fallback : decodeEnum(Edge.values, raw, 'edge', path: path);

Alignment _alignment(Object? raw, Alignment fallback, List<String> path) =>
    raw == null ? fallback : decodeAlignment(raw, path: path);
