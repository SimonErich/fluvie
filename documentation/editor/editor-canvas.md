# The canvas

The canvas is where you point at things. Everything it does writes real
geometry into the document: fractional transforms that render identically
in the editor, the presenter, and the video file.

## Tools

One key each, Figma's letters:

| Key | Tool |
| --- | --- |
| `V` | Select, move, and transform |
| `H` | Hand: drag to pan the viewport |
| `T` | Text: click to place, type inline |
| `R` | Rectangle |
| `O` | Ellipse |
| `L` | Line |
| `A` | Arrow |
| `M` | Media: insert an image or video file |

A drawing tool returns to select after each placement. Escape returns to
select from anywhere. Double-click a text element to edit it in place.

## Selection and the gizmo

Click selects. Drag on empty ground sweeps a marquee; hold Shift to add to
the selection. A selected element shows the transform gizmo: drag the body
to move, a handle to resize, the top handle to rotate. Shift locks the
aspect ratio, Alt resizes from the center, and Escape cancels the drag
without losing the selection. A multi-selection moves as one unit; handles
stay single-selection.

Arrow keys nudge by one canvas pixel, Shift+arrows by ten. A run of nudges
undoes as one step.

## Snapping, rulers, and guides

While you drag, the canvas snaps to guides, the slide edges and center,
other elements' edges and centers, and equal-spacing gaps. Snap lines pulse
as they catch. Hold Ctrl to bypass snapping for one drag.

Toggle the rulers from the toolbar. Drag off a ruler to place a guide, drag
a guide to move it, and drop it back on the ruler to remove it. Guides save
with the slide and never affect rendering.

## Groups and blocks

Select two or more elements and press `Ctrl+G` to group them. A group
moves, hides, and animates as one unit. Double-click enters the group to
edit its children; Escape leaves. `Ctrl+Shift+G` dissolves it, and the
children keep their exact places, because grouping only rewrites frames of
reference, never pixels.

The Layers list moves elements across group boundaries too: expand a group
and drag a row into its run to move the element inside, or drag a child to
a top-level slot to promote it. Nothing moves on screen either way. With
a group entered, paste and duplicate land inside it — except a pasted group
itself, which lands at the slide's top level beside the entered group.
Groups never nest by an editor gesture: move, drag, and paste hold the same
one rule.

A **block** is a group with a layout brain. The element menu's Block
submenu turns a selection into a row, column, grid, list, two-column split,
or title-with-body block. The block arranges its children and re-balances
when you add, remove, resize, or reorder them; the inspector's Block
section edits spacing, alignment, and the other knobs per kind. Blocks
nest. Drag a child out of its block's box to release it back to free
placement. The arranged positions are ordinary transforms in the document,
so a deck full of blocks renders everywhere, block-aware or not.

## Arrange

Z-order rides the brackets: `]` brings forward, `[` sends backward, with
Ctrl for all the way. Lock (`Ctrl+Shift+L`) keeps an element out of the
way of clicks; Hide (`Ctrl+Shift+H`) writes the spec's `visible: false`,
so a hidden element is honestly absent from the render. Align and
distribute live in the element menu under Align.

## Menus and the palette

Right-click anything for its menu: element commands over an element; undo,
redo, paste, and select-all over empty canvas; slide commands on a
slide-strip tile.
`Ctrl+K` opens the command palette with every command searchable, recents
on top. Menus, palette, and keyboard all fire the same registry entry, so
the shortcut a menu prints is exactly the key that works.

## Where to next

- [The timeline](editor-timeline.md): when things happen, under the canvas.
- [Shortcuts](editor-shortcuts.md): every binding on one page.
- [Free placement](../guides/free-placement.md): the `Placed` element the
  canvas writes, from the code side.
