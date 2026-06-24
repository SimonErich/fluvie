import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/media/generative_carrier.dart';
import 'package:fluvie/src/core/media/generative_source.dart';
import 'package:fluvie/src/core/time.dart';

/// Declares an AI-generated audio track (music, speech, or a sound effect) the
/// prerender pass produces before the frame loop, then folds into the encoder
/// mix as a plain file-backed track.
///
/// It is a zero-size declaration widget: place it in a `Scene`'s children. The
/// prerender pass produces its [source] through `GenerativeCarrier`, and the
/// audio collectors turn the produced file into one mix track at [volume], with
/// optional [fadeIn]/[fadeOut] and [loop]. It paints nothing.
///
/// A generated video that carries its own audio (for example Veo 3) keeps that
/// track through `GenerativeMedia`; use this widget for a *separate* generated
/// track (a Suno music bed, an ElevenLabs narration or sound effect).
///
/// `GenerativeMedia`, the audio mix, and the provider widgets are named in prose,
/// not as doc links, because they live in other layers.
final class GenerativeAudio extends StatelessWidget implements GenerativeCarrier {
  /// Declares [source] as a generated audio track at [volume].
  const GenerativeAudio({
    required this.source,
    this.volume = 1,
    this.fadeIn,
    this.fadeOut,
    this.loop = false,
    super.key,
  });

  /// The generative audio to produce (must be an audio kind).
  final GenerativeSource source;

  /// The track gain in the mix, `0..1`.
  final double volume;

  /// An optional fade-in ramp from the track's start.
  final Time? fadeIn;

  /// An optional fade-out ramp to the track's end.
  final Time? fadeOut;

  /// Whether the produced track loops to fill the composition.
  final bool loop;

  @override
  GenerativeSource? get generativeSource => source;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
