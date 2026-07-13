# Presenting on the web

The web is the "just visit and present" path. One URL, no install, works on
the podium machine you have never seen before.

The bundled slides app (the same one behind slides.fluvie.dev) boots to a
picker: choose a tutorial deck, or open a local `.fluvie` file. A `.fluvie`
file is a fluvie `VideoSpec` as JSON; the app parses it, builds the `Video`,
and presents it. Parse problems show up as a friendly message, not a stack
trace.

Everything you have read works here: keyboard and remotes fire immediately
(the presenter grabs focus on load), F drives the browser's fullscreen, and
S opens the speaker popup that syncs over a `BroadcastChannel`. The popup
loads the same app on the same origin, resolves the same deck, and follows
along.

Two browser realities to know:

- **Popups want a gesture.** Pressing S is one, so it normally just works.
  When a browser still refuses, the presenter shows the speaker URL; open it
  in any second window on the same origin.
- **Sound and autoplay policies** do not apply to slides, because slides are
  silent. If your deck embeds media with audio, the first interaction (your
  first key press) satisfies the policy.

Presenting a deck that lives in your own app instead? Mount `FluvieSlides`
anywhere in your web app; it needs nothing from the page but focus.

## Where to next

- [Deploying your own](deploying-your-own.md): put your slides app on your
  own domain.
- [The speaker window](the-speaker-window.md): the popup in detail.
