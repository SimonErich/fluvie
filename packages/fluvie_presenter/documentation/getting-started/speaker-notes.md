# Speaker notes

Drop a `SpeakerNotes` into a scene. The audience never sees it; you do.

<!-- code-excerpt "../../apps/slides/lib/decks/notes_deck.dart (speaker-notes)" -->
```dart
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
```

A `SpeakerNotes` carries two things: `text`, the prose you want in front of
you, and `highlights`, the short bullets the speaker window lists down its
side for quick glances.

The scope rule is the one you would guess:

- In a scene, the note is that slide's **default**: every step shows it.
- Inside a `Stop`, the note applies **while that step is active**. Its text
  replaces the scene text (when it has one), and its highlights are added
  after the scene's.
- Several notes in one scope merge in document order, texts joined by a
  blank line.

Press **N** while presenting to toggle the notes panel along the bottom.
On a phone or tablet that panel is your speaker view, since there is no
second window to open there.

## Where to next

- [The speaker window](../guides/the-speaker-window.md): notes, the next
  state, and a clock on your own screen.
- [Keyboard and remotes](keyboard-and-remotes.md): everything else your
  keyboard does.
