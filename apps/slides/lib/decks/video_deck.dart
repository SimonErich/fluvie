import 'package:flutter/widgets.dart' hide Animation;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:slides/decks/support/video_clip_view.dart';

const _bg = Color(0xFF14141C);
const _ink = Color(0xFFF2F2F7);
const _dim = Color(0xFF8E8E93);

/// Embedded video with sound. fluvie's `Clip` belongs to the file renderer;
/// a live talk wants a real player, so these slides embed one (an HTML
/// `video` on the web) as a plain widget child. The mp4s under
/// `assets/videos/` are gitignored — drop your own in to present them.
Video videoDeck() => Video(
  size: VideoSize.hd,
  scenes: [
    Scene(
      duration: const Time.seconds(6),
      background: Background.color(_bg),
      children: [
        const SpeakerNotes(
          text:
              'Title slide: "embedded video" in large white type, with a '
              'grey line underneath saying the next two slides hold real '
              'players with sound.',
          highlights: ['players run on their own clock', 'press play when ready'],
        ),
        const Text(
          'embedded video',
          style: TextStyle(color: _ink, fontSize: 96),
        ).animate([Animation.fadeIn(duration: const Time.seconds(0.6))]),
        Align(
          alignment: const Alignment(0, 0.35),
          child: const Text(
            'the next two slides embed real, sounding players',
            style: TextStyle(color: _dim, fontSize: 40),
          ).animate([Animation.fadeIn(delay: const Time.seconds(0.4))]),
        ),
      ],
    ),
    Scene(
      duration: const Time.seconds(8),
      background: Background.color(_bg),
      children: [
        const SpeakerNotes(
          text:
              'A video player fills the middle of the slide: the birthday '
              'clip. The caption above reads "a home video, with sound". '
              'Click play in the player controls; the audio should come '
              'through.',
          highlights: ['click play in the controls', 'sound comes through'],
        ),
        Align(
          alignment: const Alignment(0, -0.85),
          child: const Text(
            'a home video, with sound',
            style: TextStyle(color: _ink, fontSize: 48),
          ).animate([Animation.fadeIn()]),
        ),
        Align(
          alignment: const Alignment(0, 0.25),
          child: SizedBox(
            width: 1280,
            height: 720,
            child: const VideoClipView(
              assetPath: 'assets/videos/lukas_birthday_celebrate.mp4',
              label: 'the birthday clip',
            ).animate([Animation.fadeIn(duration: const Time.seconds(0.5))]),
          ),
        ),
      ],
    ),
    Scene(
      duration: const Time.seconds(8),
      background: Background.color(_bg),
      children: [
        const SpeakerNotes(
          text:
              'Same layout, second clip: the kitten mittens product video '
              'in the centered player, captioned "and a product clip". '
              'Verify seeking and volume work here too.',
          highlights: ['second player, same pattern', 'check seeking and volume'],
        ),
        Align(
          alignment: const Alignment(0, -0.85),
          child: const Text(
            'and a product clip',
            style: TextStyle(color: _ink, fontSize: 48),
          ).animate([Animation.fadeIn()]),
        ),
        Align(
          alignment: const Alignment(0, 0.25),
          child: SizedBox(
            width: 1280,
            height: 720,
            child: const VideoClipView(
              assetPath: 'assets/videos/product_clips_kitten_mittens.mp4',
              label: 'the kitten mittens clip',
            ).animate([Animation.fadeIn(duration: const Time.seconds(0.5))]),
          ),
        ),
      ],
    ),
  ],
);
