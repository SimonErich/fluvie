# FAQ

Short answers, longest first.

**Can one file really be both a video and a presentation?**
Yes. That is the design. The presenter reuses fluvie's timing engine and
plays scenes as slides; rendering the same `Video` produces the file. Two
details differ live: the presenter paces by input instead of scene
durations, and `Stop`s (passthroughs in a render) become steps.

**Why can't elements inside a Stop use `Trigger.whenEnds`?**
A revealed step resolves its animations at the moment you click, locally.
There is no composition plan at that moment to look another element up in.
Use a `delay:` or `Trigger.previous` on the same element; the compiler
points at the exact element when you forget.

**Why did my `0.3.relative` animation crawl?**
Relative times resolve against the enclosing scene, and the presenter
stretches each scene so slides can hold indefinitely. Use absolute times in
decks (`0.5.seconds`, `12.frames`). The compiler cannot catch this one, so
the habit matters.

**Does going back replay animations in reverse?**
No. Back and jumps land on the held state: content settled, ambient motion
running. Only forward plays entrances. Audiences read reverse animation as
a glitch, so the presenter does not do it.

**The speaker popup did not open.**
Your browser blocked it. The presenter shows the speaker URL instead; open
it in a second window on the same origin and everything syncs the same way.

**How do I get the speaker window on desktop?**
Ship a launcher: implement `SpeakerWindowLauncher`, open your second window
(for example with `desktop_multi_window`, registering plugins per window as
its README shows), mount `FluvieSpeaker` with the same deck there, and
override `speakerWindowLauncherProvider`. Until then, S shows the URL
instruction, which works against a web deployment of the same deck.

**Where do `.fluvie` files come from?**
They are fluvie `VideoSpec` documents as JSON, the authoring-as-data format
(`fluvie_ai` generates them, `VideoSpec.fromJson` + `buildVideo` load them).
The bundled app opens them from disk on any platform.

**Does presenting need audio, beat triggers, or captions?**
No, and beat triggers do not work in decks (there is no analysed audio at
presentation time; the compiler reports them inside stops, the resolver
elsewhere). Slides are silent; your voice is the soundtrack.

**Can I theme the chrome?**
`FluvieSlides(theme: PresenterTheme(tokens: ..., stageBackground: ...))`.
The tokens are obers_ui `OiThemeData`, so the chrome follows your design
system; the stage color is the letterbox behind slides.

## Where to next

- [Present your first video](../getting-started/present-your-first-video.md):
  if you got here before starting.
- [How stepping works](../advanced/how-stepping-works.md): the honest
  mechanics behind these answers.
