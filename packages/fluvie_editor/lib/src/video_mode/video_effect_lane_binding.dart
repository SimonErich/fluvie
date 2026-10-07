import 'package:fluvie/fluvie.dart' show FrameSpan;
import 'package:meta/meta.dart';

/// Joins one effect bar back to the document: the element, which entry of
/// its `effects` list, the absolute window the bar spans (the element's own
/// alive-window — an effect has no span of its own), and where every
/// keyframed parameter's stops sit in bar-relative frames.
///
/// [stopFramesByParam] is what the diamond edits read: a move needs the
/// whole list to clamp between neighbors, and an insert needs it to find the
/// segment it splits.
@immutable
final class VideoEffectLaneBinding {
  /// Creates the binding.
  const VideoEffectLaneBinding({
    required this.elementId,
    required this.effectIndex,
    required this.window,
    required this.stopFramesByParam,
  });

  /// The element carrying the effect.
  final String elementId;

  /// Which entry of the element's `effects` list this bar draws.
  final int effectIndex;

  /// The absolute frames the bar spans — the element's alive-window.
  final FrameSpan window;

  /// Every keyframed parameter's stop frames, bar-relative, in document
  /// key order. Empty when nothing on the effect is keyframed.
  final Map<String, List<int>> stopFramesByParam;
}

/// Joins one diamond back to the stop it draws: the element, the effect,
/// the keyframed parameter, and the stop's index in its `values` list.
@immutable
final class VideoEffectDiamondBinding {
  /// Creates the binding.
  const VideoEffectDiamondBinding({
    required this.elementId,
    required this.effectIndex,
    required this.param,
    required this.stop,
  });

  /// The element carrying the effect.
  final String elementId;

  /// Which entry of the element's `effects` list holds the parameter.
  final int effectIndex;

  /// The keyframed parameter's name.
  final String param;

  /// The stop's index in the parameter's `values` list.
  final int stop;
}
