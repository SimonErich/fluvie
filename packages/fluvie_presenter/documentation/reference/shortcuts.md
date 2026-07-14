# Shortcuts

Everything the presenter listens for. Presenter remotes send PageUp,
PageDown, F5, and period, so they are covered by the same table.

## Moving

| Input | Does |
| --- | --- |
| Right, Down, Space, PageDown, Enter | Next step or slide |
| Tap, swipe left | Next step or slide |
| Left, Up, Shift+Space, PageUp | Back (instant, held state) |
| Swipe right | Back |
| Home | First slide |
| End | Last slide |
| digits, then Enter | Jump to that slide number |

While digits are pending, Esc clears them instead of escaping.

## Screen

| Input | Does |
| --- | --- |
| F, F5 | Toggle fullscreen |
| B, . | Toggle black screen |
| W | Toggle white screen |
| Esc | Close the topmost overlay, else leave fullscreen |

## Chrome

| Input | Does |
| --- | --- |
| O | Toggle the overview grid |
| S | Open the speaker window |
| T | Toggle the slide sidebar |
| N | Toggle the notes panel |
| H | Toggle the HUD: counter, progress line, and buttons |

The same five chrome actions sit as small buttons in the top-right corner
of the stage, so a mouse works too (plus a close button, set apart, when
the host app wired `onClose`). H hides them with the rest of the HUD. In
fullscreen the buttons fade out after four seconds; hovering their corner
brings them back for five.

Navigation clears an active black or white screen (and the speaker-window
notice) before it moves, so one key press always brings the slides back.

## Where to next

- [Keyboard and remotes](../getting-started/keyboard-and-remotes.md): the
  guided tour of the same table.
- [FAQ](faq.md): the questions the table raises.
