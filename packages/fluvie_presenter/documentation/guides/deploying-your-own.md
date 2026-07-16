# Deploying your own

The bundled app under `apps/slides` is a complete deployable shell: a deck
picker, a `.fluvie` loader, the presenter, and the speaker route. Fork it or
copy the three ideas out of it.

Build it for the web like any Flutter app:

```text
cd apps/slides
flutter build web --release
```

Host `build/web/` on anything static. The speaker popup opens
`<your-origin>/<path>#/speaker`, so no extra route configuration is needed;
it is the same page deciding at startup which root to mount:

- the presenting shell by default, or
- the speaker shell when the URL fragment says `#/speaker`.

The main window records what it presents (a bundled deck id, or the opened
file's JSON) in `localStorage`; the popup on the same origin reads it and
mounts `FluvieSpeaker` on the same deck. If you deploy your own shell,
keep that handoff or replace it with your own routing; the presenter does
not care where the deck comes from.

Desktop builds work the same way (`flutter build linux`, and friends). The
one desktop difference is the speaker window: ship your own launcher for it
(see [the speaker window](the-speaker-window.md)); until you do, S shows
the URL instruction, which still works against your web deployment.

For your own decks, either bundle them as Dart (like the tutorial decks in
`lib/decks/`) or serve `.fluvie` files people can open from the picker.

## Where to next

- [Presenting on the web](presenting-on-the-web.md): what the deployed app
  feels like.
- [FAQ](../reference/faq.md): the operational questions.
