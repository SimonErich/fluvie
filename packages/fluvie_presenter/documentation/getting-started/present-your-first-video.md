# Present your first video

You already have the hard part: a `Video`. Presenting it is one widget.

<!-- code-excerpt "../../apps/slides/lib/snippets/presenter_snippets.dart (five-lines)" -->
```dart
void presentIt(Video video) {
  runApp(FluvieSlides(video));
}
```

That is the whole program. Every scene in your video is a slide. Arrow keys,
Space, a click, or a presenter remote move you forward; Left and Up go back.
Press F for fullscreen when the projector is watching.

A slide does not rush you. Its entrances play when the slide appears, ambient
motion keeps breathing, and then the slide waits for you. The authored scene
durations still matter when you render the same file as a video; presenting
just paces it by hand instead.

Here is a full deck from the bundled tutorials, three plain slides:

<!-- code-excerpt "../../apps/slides/lib/decks/welcome_deck.dart (plain-slides)" -->
```dart
Video welcomeDeck() => Video(
  size: VideoSize.hd,
  scenes: [
    Scene(
      duration: const Time.seconds(6),
      background: Background.color(_bg),
      children: [
        const Text(
          'fluvie slides',
          style: TextStyle(color: _ink, fontSize: 120),
        ).animate([Animation.fadeIn(duration: const Time.seconds(0.6)), Animation.float()]),
        Align(
          alignment: const Alignment(0, 0.35),
          child: const Text(
            'a Video, presented live',
            style: TextStyle(color: _dim, fontSize: 44),
          ).animate([Animation.fadeIn(delay: const Time.seconds(0.4))]),
        ),
      ],
    ),
    Scene(
      duration: const Time.seconds(6),
      background: Background.color(_bg),
      children: [
        const Text(
          'every scene is a slide',
          style: TextStyle(color: _ink, fontSize: 72),
        ).animate([Animation.slideFadeIn()]),
        Align(
          alignment: const Alignment(0, 0.4),
          child: const Text(
            'arrows, space, or a remote to move. F for fullscreen',
            style: TextStyle(color: _dim, fontSize: 36),
          ).animate([Animation.fadeIn(delay: const Time.seconds(0.5))]),
        ),
      ],
    ),
    Scene(
      duration: const Time.seconds(6),
      background: Background.color(_bg),
      children: [
        Align(
          alignment: const Alignment(0, -0.5),
          child: const Text(
            'and the same file still renders as a video',
            style: TextStyle(color: _ink, fontSize: 56),
          ).animate([Animation.fadeIn()]),
        ),
        const Box(
          color: _accent,
          size: Size(0.4, 0.08),
        ).animate([Animation.slideFadeIn(delay: const Time.seconds(0.4))]),
      ],
    ),
  ],
);
```

Nothing in it knows about the presenter. That is the point: you write a
video, and presenting is something you do *to* it.

## The config surface

The constructor takes four things and stays that small on purpose:

<!-- code-excerpt "../../apps/slides/lib/snippets/presenter_snippets.dart (config-flags)" -->
```dart
Widget configured(Video video) => FluvieSlides(
  video,
  showSidebar: true, // the slide list starts open (T toggles it)
  showNotes: true, // the notes panel starts open (N toggles it)
  startFullscreen: true, // request fullscreen once mounted
  theme: PresenterTheme(
    tokens: OiThemeData.dark(), // obers_ui tokens for the chrome
    stageBackground: const Color(0xFF0B2027), // behind the letterboxed slide
  ),
);
```

## Where to next

- [Builds with Stop](builds-with-stop.md): reveal content one click at a
  time.
- [Speaker notes](speaker-notes.md): the panel your audience never sees.
- [Keyboard and remotes](keyboard-and-remotes.md): the full input map.
