# Themes, masters, and templates

One palette should restyle a whole deck. The editor gets there with three
layers: theme tokens for values, masters for slide layouts, and templates
for complete starting decks. All three are spec data, so a themed deck
renders themed everywhere, not just on this canvas.

## Theme tokens

The Theme tab (third tab on the left, next to Slides and Layers) edits the
document's `theme` block: a color palette, a type scale, spacing, and
motion defaults. Every color field in the inspector leads with the palette;
tap a token and the field binds to it as `{"token": "accent"}` instead of a
literal. A bound field shows the token as a chip; unbind it and the
resolved literal is written back.

Change the token's value and every bound color in the deck follows, slide
thumbnails included. Renaming a token rewrites every reference in one undo
step, and removing a token that is still referenced is refused, because a
dangling reference would fail the next render loudly.

Three builtin themes ship as starting points: midnight, paper, and neon.
They share one token vocabulary, so "Start from" restyles the same bound
deck rather than resetting it.

## The gradient editor

Gradient backgrounds edit in a dedicated widget: a stops bar you drag, tap
to add a stop (it samples the gradient there), drag a stop well below the
bar to remove it, a numeric angle for linear gradients, and a radial mode.
Dragging a stop writes its offset into the spec's `stops` list; while every
stop sits at its even-spacing position the list stays out of the document.
Stops you did not touch keep their exact JSON, so token-bound gradient
colors survive edits to their neighbors.

## Masters

A master is a named slide layout: fixed chrome plus named placeholder
slots. A slide adopts a master by name and fills its slots; editing the
master changes every adopting slide, because adoption happens at build
time, never by copying.

The slide strip grows a masters row once masters exist: apply one to the
current slide, or open it in master-edit mode, where the same canvas and
inspector edit the master itself. Placeholders show as labeled outline
boxes. On an adopting slide, an unfilled slot is a click target: a text
slot types straight in, a media slot asks for a file. A filled slot is a
first-class element, and deleting it unfills the slot.

Applying a different master, or detaching one, never loses content: fills
whose slots survive stay fills, and orphaned content is promoted to plain
slide elements where it stood.

## Templates

**New from template** on the start screen opens a gallery of complete decks
(a pitch, a report, a portfolio, a master starter), each carrying its own
theme and masters over the builtin token vocabulary. A slide tile's menu
can also insert a single template slide into the open deck; the tokens and
masters the deck is missing merge in additively, and the deck's own entries
always win on collision.

## Auto-animate

With nothing selected, the inspector shows the slide's Auto-animate
section. Switch on "Match previous slide" and the editor pairs this slide's
elements with the previous slide's, explicit shared ids first, then
same-content matches, and writes shared-element ids on both sides so the
pair morphs across the slide boundary. Preview morph plays the real
transition in a dialog; the file render and the presenter play the same
morph, one machinery.

The engine never invents motion: unmatched elements ride the slide's
authored transition. The Morph row on a selected element links or unlinks a
pair by hand, and manual links survive switching the toggle off.

## Where to next

- [Theming](../advanced/theming.md): the same token idea on the code side.
- [Editor getting started](editor-getting-started.md): where the tabs and
  the start screen live.
- [The canvas](editor-canvas.md): editing the elements the theme colors.
