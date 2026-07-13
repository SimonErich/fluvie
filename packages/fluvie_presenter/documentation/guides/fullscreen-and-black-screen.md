# Fullscreen and black screen

Two keys own the room.

**F** toggles fullscreen. On the web that is the browser Fullscreen API (the
key press counts as the user gesture browsers require). On desktop the
window itself goes fullscreen. On Android and iOS the system bars leave in
immersive mode and come back when you exit. Presenter remotes usually send
F5 for their "start show" button; that toggles fullscreen too. **Esc**
leaves fullscreen, after it has closed any overlay first.

`FluvieSlides(video, startFullscreen: true)` requests fullscreen as soon as
the presenter mounts, for kiosk-style setups. Browsers may still insist on
one interaction first; the F key is always there.

**B** (or the **.** every remote has) covers the stage in black. **W**
covers it in white, for rooms where black reads as "the projector died".
The presentation holds exactly where it was: the same key again, Esc, or
any navigation lifts the cover and you are back mid-thought. Use it when
you want eyes on you instead of the slide.

## Where to next

- [Keyboard and remotes](../getting-started/keyboard-and-remotes.md): the
  complete input map.
- [Presenting on the web](presenting-on-the-web.md): fullscreen quirks
  browsers bring.
