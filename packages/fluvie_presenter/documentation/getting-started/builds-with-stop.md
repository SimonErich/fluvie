# Builds with Stop

Sometimes a slide should not say everything at once. Wrap the part that
waits in a `Stop`:

<!-- code-excerpt "../../apps/slides/lib/decks/builds_deck.dart (builds-with-stop)" -->
```dart
Video buildsDeck() => Video(
  size: VideoSize.hd,
  scenes: [
    Scene(
      duration: const Time.seconds(8),
      background: Background.color(_bg),
      children: [
        Align(
          alignment: const Alignment(0, -0.6),
          child: const Text(
            'reveal on click',
            style: TextStyle(color: _ink, fontSize: 72),
          ).animate([Animation.fadeIn()]),
        ),
        Stop.single(
          child: Align(
            alignment: const Alignment(0, -0.1),
            child: _bullet(
              'each Stop is one step',
              _accent,
            ).animate([Animation.slideFadeIn(from: Edge.left)]),
          ),
        ),
        Stop.single(
          child: Align(
            alignment: const Alignment(0, 0.15),
            child: _bullet(
              'it plays its own entrance',
              _teal,
            ).animate([Animation.slideFadeIn(from: Edge.left)]),
          ),
        ),
        Stop.single(
          child: Align(
            alignment: const Alignment(0, 0.4),
            child: _bullet(
              'going back lands on the held state',
              _dim,
            ).animate([Animation.slideFadeIn(from: Edge.left)]),
          ),
        ),
      ],
    ),
    Scene(
      duration: const Time.seconds(6),
      background: Background.color(_bg),
      children: [
        const Text(
          'ambient motion never pauses',
          style: TextStyle(color: _ink, fontSize: 64),
        ).animate([Animation.fadeIn(), Animation.float()]),
        Stop.single(
          child: Align(
            alignment: const Alignment(0, 0.45),
            child: const Text(
              'even while a step holds',
              style: TextStyle(color: _dim, fontSize: 36),
            ).animate([Animation.pop()]),
          ),
        ),
      ],
    ),
  ],
);
```

Each `Stop` becomes one step of its slide, in the order you wrote them (give
a `Stop` an explicit `order:` to jump the queue). Before its step, the
content is simply not there. On your click it appears and plays the entrance
you authored on it, from that exact moment. This is the PowerPoint and
reveal.js build model, with fluvie animations doing the moving.

Three things worth knowing:

- **Going back never rewinds.** Back and sidebar jumps land on the held
  state: everything up to that step visible, settled, with ambient motion
  still running. Forward is animated, backward is instant. That is how good
  presentations behave.
- **A `Stop` can hold several children.** They reveal together, stacked like
  scene children. `Stop.single(child: ...)` is the one-child shorthand.
- **Nested stops are later steps.** A `Stop` inside a `Stop` reveals after
  its parent, in document order.

One constraint, and the compiler tells you when you hit it: elements inside
a `Stop` resolve their timing locally when they reveal, so they cannot use
`Trigger.whenEnds`, `Trigger.whenStarts`, or `Trigger.beat`. Use a `delay:`
(or `Trigger.previous` on the same element) and the choreography reads the
same.

When you render the deck as a video file instead, every `Stop` is a
transparent passthrough: the full scene plays on its authored timeline.

## Where to next

- [Speaker notes](speaker-notes.md): a note per step, if you want one.
- [How stepping works](../advanced/how-stepping-works.md): the clock model
  underneath, if you like knowing.
