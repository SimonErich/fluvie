import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:meta/meta.dart';

/// One audio track on a `Video` or `Scene`: background music or a
/// one-shot sound effect.
///
/// A declared track is staged into the encoder's audio mix by default, so the
/// rendered file carries sound. Every track is materialized before the frame
/// loop and combined with `amix`, so multiple tracks layer and mix into one
/// output stream. A beat-tagged music track (see [track]) is analysed before
/// frame 0 into a beat grid that `Trigger.beat(track: ...)` resolves against.
@immutable
final class Audio {
  /// A music bed playing for the lifetime of its owner.
  ///
  /// [volume] is a linear gain (1 = as authored), [fadeIn]/[fadeOut] ramp the
  /// ends, [loop] repeats the file to fill the owner's duration, [trim] plays
  /// only that range of the file, and [track] names this track so
  /// `Trigger.beat(track: ...)` can resolve against its analysed beat grid.
  const Audio.music(
    this.source, {
    this.volume = 1,
    this.fadeIn,
    this.fadeOut,
    this.loop = false,
    this.trim,
    this.track,
  }) : at = null,
       _sfx = false;

  /// A one-shot sound effect fired [at] a trigger, at [volume].
  const Audio.sfx(this.source, {this.at, this.volume = 1})
    : fadeIn = null,
      fadeOut = null,
      loop = false,
      trim = null,
      track = null,
      _sfx = true;

  /// Where the audio comes from: an asset path, file path, or URL.
  final String source;

  /// Linear gain applied to the track; `1` plays the file as authored.
  final double volume;

  /// How long the track ramps in from silence; `null` starts at full volume.
  final Time? fadeIn;

  /// How long the track ramps out to silence; `null` stops at full volume.
  final Time? fadeOut;

  /// Whether a music bed repeats to fill its owner's duration.
  final bool loop;

  /// The range of the source file to play; `null` plays the whole file.
  final TimeRange? trim;

  /// Names this track's timeline and its analysed beat grid so triggers can
  /// reference it; `null` leaves the track unnamed.
  final Anchor? track;

  /// When a sound effect fires; `null` on music, and on an sfx it defaults to
  /// its owner's start.
  final Trigger? at;

  final bool _sfx;

  /// Whether this track is a one-shot [Audio.sfx] rather than a music bed.
  bool get isSfx => _sfx;

  /// This track's [source] string resolved to a typed, validated
  /// [AudioSource] by its shape:
  ///
  /// - an `http`/`https` URL becomes an [AudioSource.network],
  /// - a path starting with `/` becomes an [AudioSource.file],
  /// - anything else becomes a bundled [AudioSource.asset].
  ///
  /// Throws a [FluvieRenderException] naming the track when [source] is empty
  /// or a network URL has no host — the encoder must never be handed a blank or
  /// hostless `-i`.
  AudioSource get audioSource {
    if (source.isEmpty) {
      throw FluvieRenderException(
        'Audio source is empty${track == null ? '' : " on track '$track'"}. '
        'Give Audio.music/Audio.sfx an asset key, file path, or URL.',
      );
    }
    final uri = Uri.tryParse(source);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      if (uri.host.isEmpty) {
        throw FluvieRenderException('Audio network URL "$source" has no host to fetch.');
      }
      return AudioSource.network(uri);
    }
    if (source.startsWith('/')) return AudioSource.file(source);
    return AudioSource.asset(source);
  }

  @override
  String toString() =>
      _sfx ? 'Audio.sfx($source, at: $at, volume: $volume)' : 'Audio.music($source)';
}
