# The speaker window

The audience gets the stage. You get more: what the next click produces, your
notes, the highlight bullets down the side, where you are in the deck, and a
clock that has been counting since you started.

Press **S**.

On the **web** that opens a popup on the speaker route and the two windows
talk over a broadcast channel. Either window can advance; they stay in
lockstep either way. Drag the popup to your laptop screen, put the stage on
the projector, and present.

If the browser blocks the popup (they like a user gesture, and they got one,
but browsers will be browsers), the presenter shows the speaker URL instead:
open that link in a second window yourself and everything else is identical.

On **desktop** the presenter ships the seam, and your app supplies the
opener: override `speakerWindowLauncherProvider` with a launcher that creates
the second window (see [custom navigation](../advanced/custom-navigation.md)
for the provider pattern, and the [FAQ](../reference/faq.md) for the
multi-window notes). Without one, S shows the same URL instruction.

On **mobile** there is no second window to open, so S surfaces the in-app
notes panel. Same notes, smaller room.

The speaker window itself is one widget, in case you deploy it standalone:

<!-- code-excerpt "../../apps/slides/lib/snippets/presenter_snippets.dart (speaker-root)" -->
```dart
Widget speakerWindow(Video video) => FluvieSpeaker(video);
```

Mount it with the same deck the stage presents. It compiles the same plans
and notes, follows position updates, and sends its own inputs back as
navigation requests.

## Where to next

- [Presenting on the web](presenting-on-the-web.md): the popup's natural
  habitat.
- [Speaker notes](../getting-started/speaker-notes.md): what fills the panel.
