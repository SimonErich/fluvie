import 'package:flutter/widgets.dart' hide Animation;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

const _bg = Color(0xFF14141C);
const _ink = Color(0xFFF2F2F7);
const _dim = Color(0xFF8E8E93);

/// Lesson three: speaker notes. The audience never sees them; N shows the
/// panel, S opens the speaker window.
// #docregion speaker-notes
Video notesDeck() => Video(
  size: VideoSize.hd,
  scenes: [
    Scene(
      duration: const Time.seconds(8),
      background: Background.color(_bg),
      children: [
        const SpeakerNotes(
          text:
              'Open with the outage story. Keep it light: the point is how '
              'fast the fix shipped once someone could see the timeline.',
          highlights: ['3am page', '14 services down', 'one line fix'],
        ),
        const Text(
          'the incident review',
          style: TextStyle(color: _ink, fontSize: 80),
        ).animate([Animation.fadeIn()]),
        Stop(
          children: [
            // A note inside a Stop takes over while its step is active.
            const SpeakerNotes(text: 'Now the numbers. Pause after each one.'),
            Align(
              alignment: const Alignment(0, 0.35),
              child: const Text(
                '41 minutes, start to fix',
                style: TextStyle(color: _dim, fontSize: 48),
              ).animate([Animation.slideFadeIn()]),
            ),
          ],
        ),
      ],
    ),
    Scene(
      duration: const Time.seconds(6),
      background: Background.color(_bg),
      children: [
        const SpeakerNotes(
          text: 'Close by pointing at the postmortem doc. Questions here.',
          highlights: ['link in chat', 'take questions'],
        ),
        const Text(
          'what we changed',
          style: TextStyle(color: _ink, fontSize: 72),
        ).animate([Animation.fadeIn()]),
      ],
    ),
  ],
);
// #enddocregion speaker-notes
