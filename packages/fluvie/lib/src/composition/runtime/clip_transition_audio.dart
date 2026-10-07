import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/runtime/collectible_children.dart';
import 'package:fluvie/src/core/audio/audio_automation.dart';
import 'package:fluvie/src/core/media/clip_audio.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/serialization/element_transition_spec.dart';

/// Equal-power transition gains multiplied by the authored volume envelope.
AudioAutomation transitionAudioAutomation({
  required String id,
  required AudioAutomation automation,
  required ({int start, int end}) window,
  required List<ElementTransitionWindow> blends,
  required int fps,
}) {
  final duration = window.end - window.start;
  final original = automation.resolve(fps: fps, windowFrames: duration);
  ({int start, int end}) audioWindow(ElementTransitionWindow blend) {
    if (!blend.transition.overlap && blend.outgoing == id) {
      return (start: window.end - (blend.end - blend.start), end: window.end);
    }
    return (start: blend.start, end: blend.end);
  }

  final frames = <int>{
    0,
    duration,
    for (final point in original) (point.seconds * fps).round().clamp(0, duration),
    for (final blend in blends)
      for (var frame = audioWindow(blend).start; frame <= audioWindow(blend).end; frame++)
        (frame - window.start).clamp(0, duration),
  }.toList()..sort();
  final values = <double>[];
  for (final frame in frames) {
    var value = audioVolumeAt(original, frame / fps);
    final absolute = window.start + frame;
    for (final blend in blends) {
      final fade = audioWindow(blend);
      final progress = ((absolute - fade.start) / (fade.end - fade.start)).clamp(0.0, 1.0);
      value *= blend.outgoing == id
          ? math.cos(progress * math.pi / 2)
          : math.sin(progress * math.pi / 2);
    }
    values.add(value.clamp(0.0, 1.0));
  }
  return AudioAutomation(
    values: values,
    positions: [for (final frame in frames) Time.frames(frame)],
  );
}

/// Makes transition audio available through both mounted and structural walks.
final class ClipTransitionAudioScope extends InheritedWidget implements CollectibleChildren {
  /// Binds the effective clip window and its transition gain to normal children.
  const ClipTransitionAudioScope({
    required this.id,
    required this.window,
    required this.blends,
    required this.fps,
    required super.child,
    super.key,
  });

  /// Clip identity.
  final String id;

  /// Effective parent-local window.
  final ({int start, int end}) window;

  /// Transitions attached to this clip.
  final List<ElementTransitionWindow> blends;

  /// Parent frame rate.
  final int fps;

  /// Preserves static gain, authored fades, automation and mute policy.
  ClipAudio audioFor(ClipAudio audio) => audio.muted
      ? audio
      : ClipAudio.included(
          volume: audio.volume,
          fadeIn: audio.fadeIn,
          fadeOut: audio.fadeOut,
          automation: transitionAudioAutomation(
            id: id,
            automation: audio.automation,
            window: window,
            blends: blends,
            fps: fps,
          ),
        );
  @override
  Iterable<Widget> get collectibleChildren => [child];
  @override
  bool updateShouldNotify(ClipTransitionAudioScope oldWidget) =>
      id != oldWidget.id ||
      window != oldWidget.window ||
      !identical(blends, oldWidget.blends) ||
      fps != oldWidget.fps;
}
