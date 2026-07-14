# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- Slides no longer replay their entrance after a boundary transition: the
  incoming stage now survives the blend settling (it reparents instead of
  remounting), so its clock never restarts.

### Added

- The HUD grew a small top-right control strip: sidebar, notes, overview,
  speaker window, and fullscreen as clickable buttons with the shortcut in
  the tooltip. H hides it with the rest of the HUD.
- `FluvieSlides(onClose:)`: wire it and the strip shows a close button,
  set apart on the right.
- In fullscreen the strip gets out of the way: it fades after four
  seconds, and hovering its corner brings it back for five.
- Slide previews highlight under the mouse (accent border and a soft
  tint), in the sidebar and the overview alike.

- `FluvieSlides`: present a fluvie `Video` live — one scene per slide,
  letterboxed on a flat obers_ui stage, with the full keyboard/remote/touch
  input map.
- `Stop`: PowerPoint-style builds — hidden until its step, then the authored
  entrance plays from the reveal moment; backs and jumps land on held states
  while ambient motion keeps running.
- `SpeakerNotes` + the notes compiler and togglable notes panel (scene
  defaults, per-step overrides).
- The slide sidebar and overview grid over one lazy, capped preview cache.
- Fullscreen behind one interface (web / desktop / mobile) and black/white
  screen covers.
- `FluvieSpeaker` + `PresentationSyncChannel`: the speaker window with the
  next-state preview, notes, highlights, and an elapsed clock — a synced
  popup on the web, an app-pluggable launcher elsewhere, and an
  open-this-URL fallback.
- `PresentationController`, `compileSlidePlans`, and `compileNotes` as the
  public engine surface for custom chrome.
