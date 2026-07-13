# How stepping works

You can present forever without this page. Read it when you want to know
why holds never freeze and backs never rewind.

## One clock, never paused

Fluvie renders every frame as a pure function of a frame index. A video file
walks that index with an encoder; the presenter walks it with a real clock.
The trick is what "hold" means.

Each slide mounts as its own single-scene composition, with the scene's
duration stretched to a huge horizon. The clock starts at zero when the
slide appears and simply never stops. Entrances play (they sit at the start
of the timeline), ambient `during` loops keep looping (their window is the
whole stretched scene), and exits never fire (they anchor to the horizon,
which never arrives). "Holding" is not a paused clock; it is a running clock
with nothing left scheduled. That is why the floaty title keeps floating
while you talk.

## Reveals rebase the clock

A hidden `Stop` renders nothing. When its step arrives, its children mount
on a rebased clock: the subtree sees frame zero at the reveal moment, so
the entrances you authored play right then, exactly as written. Everything
inside one `Stop` shares one rebase, so its internal choreography (delays,
`Trigger.previous` chains) survives intact.

Backward moves and jumps use the same mechanism with a settle offset: the
subtree mounts with its clock already past its entrances. Settled content,
ambient still alive, nothing replayed. The two paths meet at the same
pixels, and a test pins that byte for byte.

## What the compiler checks

`compileSlidePlans` walks each scene before anything mounts: it orders the
stops, measures each step's entrance length from the resolved timeline, and
rejects the two setups a live reveal cannot honor: duplicate explicit
`order:`s, and cross-element or beat triggers on stopped elements (a reveal
resolves locally, so it cannot wait on another element's timeline).

Two authored details read differently on the stretched scene, so decks
should avoid them: relative `Time`s (write `1.seconds`, not `0.3.relative`),
and scene-duration choreography (the presenter paces by input, not by the
authored length). Rendering the same deck as a video file uses the authored
durations, untouched.

## Slide changes are presenter blends

The compositor's scene transitions assume the authored timeline; a live
deck holds stepped states the timeline never had. So the presenter blends
slide changes itself, mapped from your authored `Transition`: crossFade
fades the incoming slide in, slide pushes it from its edge, wipe uncovers
it, zoom scales the outgoing one away. Same kind, duration, and ease;
`SlideView(playTransitions: false)` cuts instead.

## Where to next

- [Builds with Stop](../getting-started/builds-with-stop.md): the authoring
  view of the same machinery.
- [Custom navigation](custom-navigation.md): driving the deck yourself.
