import 'package:flutter/material.dart' hide Animation, Image;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/lessons/lesson.dart';

const _title = TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold);
const _label = TextStyle(color: Color(0xFF9AA7B4), fontSize: 28);

/// The bundled WAV the music bed plays and the beat pre-pass analyses. It is a
/// short, deterministic kick loop, so the in-house DSP reads identical band and
/// beat data on every render with no ffmpeg.
const _track = 'assets/audio/beat_loop.wav';

/// The bundled SubRip file the caption pre-pass reads and parses before frame 0.
const _captions = 'assets/audio/lesson10.srt';

/// The caption look: a plain, readable lower-third subtitle band.
const _captionStyle = CaptionStyle.subtitle();

/// Lesson 10 — audio and captions: a music bed whose beat
/// drives the picture, a bar visualizer and a pulsing badge that react to the
/// bass band, and a subtitle track read from an SRT file.
///
/// Every reactive input is computed once before frame 0: the WAV is decoded by
/// the in-house reader, the spectral-flux beat detector and the band analyzer
/// run over it, and the SRT is parsed — all offline, with no ffmpeg in the gate.
/// The frame loop only reads those immutable tables, so the lesson renders
/// deterministically.
const lesson10AudioAndCaptions = Lesson(
  id: '10_audio_and_captions',
  title: 'Audio and captions',
  intro:
      'A music bed whose beat is found before frame zero, a bar visualizer and '
      'a badge that pulse on the bass band, and subtitles read from an SRT '
      'file. The audio is analysed once in a pre-pass and the frame loop only '
      'reads the result, so the picture reacts to the beat deterministically.',
  video: lesson10Video,
);

/// Builds the lesson 10 composition: a single 6 second 16:9 scene with a music
/// bed, beat-reactive visuals, and an SRT caption track.
///
/// The [Audio.music] bed is both played (mixed by the encoder) and analysed (by
/// the reactive pre-pass) — [Bars] reads the bass band's per-frame energy and
/// the badge [Animation.pulse]s on the same band. The [Captions.fromSrt] track
/// mounts as the top scene-spanning overlay, its cues parsed before the frame
/// loop. `poster: 2.seconds` lands on a bass beat, so the gallery still shows
/// the visuals at a peak.
Video lesson10Video() {
  return Video(
    size: VideoSize.hd,
    poster: 2.seconds,
    // #docregion music
    audio: const [
      Audio.music(_track, fadeIn: Time.seconds(0.3), fadeOut: Time.seconds(0.5)),
    ],
    // #enddocregion music
    // #docregion captions
    captions: const Captions.fromSrt(_captions, style: _captionStyle),
    // #enddocregion captions
    scenes: [_reactiveScene()],
  );
}

/// The one scene: a title, a bass-reactive badge, and the bar visualizer.
Scene _reactiveScene() => Scene(
  duration: 6.seconds,
  background: Background.gradient(const [Color(0xFF120A2A), Color(0xFF2A1346)]),
  children: [
    const Positioned(top: 56, left: 64, child: Text('On the beat', style: _label)),
    Center(child: _badge()),
    Positioned(left: 96, right: 96, bottom: 140, height: 220, child: _bars()),
  ],
);

/// The headline badge that pops on every bass beat.
///
/// [Animation.pulse] with an [AudioBand] is the reactive pulse: each frame it
/// scales the badge by `1 + bassEnergy · gain` read from the precomputed band
/// table, so it grows on the kick and settles between beats — no live audio in
/// the frame.
Widget _badge() =>
    const Text('BASS', style: _title)
    // #docregion pulse
    .animate([Animation.fadeIn(), Animation.pulse(on: AudioBand.bass, gain: 0.4)]);
// #enddocregion pulse

/// The bar visualizer reacting to the bass band.
///
/// [Bars] reads the same precomputed band table the badge does, scaling each
/// bar by the current frame's bass energy ([AudioBand.bass] is the default
/// band). With no [Bars.track] it reads the master mix (the single music bed
/// here).
// #docregion bars
Widget _bars() => const Bars(count: 32, gain: 1.2);
// #enddocregion bars
