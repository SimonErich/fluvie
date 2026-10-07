# ADR: build steps, speaker notes, and the digest

Status: accepted, 2026-07-19.

This page fixes the `.fluvie` shape for build steps and speaker notes. It
also pins which keys count into the render digest. The presenter and the
editor both build on these shapes. The format version and its migration
hook absorb any later change.

## The decision in one look

```json
{
  "duration": "8s",
  "children": [
    { "id": "el-title", "type": "Text", "text": "Incident review" },
    { "id": "el-b1", "type": "Text", "text": "3am page" },
    { "id": "el-b2", "type": "Text", "text": "one line fix" }
  ],
  "steps": [
    { "elements": ["el-b1"] },
    { "elements": ["el-b2"], "notes": { "text": "Land the punchline." } }
  ],
  "notes": {
    "text": "Open with the outage story.",
    "highlights": ["3am page", "one line fix"]
  }
}
```

## Steps are scene-level ordered groups of element ids

A scene may carry a `steps` list. Each entry is an object with two keys:

- `elements` (required): the ids of the scene children this step reveals.
  Every id must name a child of the same scene. An id appears in at most
  one step. Children not named in any step are step 0 and show on entry.
- `notes` (optional): the per-step notes override. The shape is below.

The list order is the step order. There is no `order` key. The widget
model needs `Stop.order` because document position is its only other
signal. A JSON list already is an explicit order, and a second ordering
mechanism would only add ways to disagree.

Steps reference ids instead of nesting the children. The editor addresses
elements by id for transforms, selection, and layers. Steps are
presentation metadata over those same children, not a structural
container. Nesting would force every canvas tool to look through a
wrapper. Ids keep the children list flat, and the id groups are exactly
what the presenter needs to build its `Stop` wrappers.

## Notes are a scene default plus per-step overrides

A notes object has two optional keys, matching `SpeakerNotes`:

- `text`: the full prose for the speaker.
- `highlights`: the glanceable bullet list.

The scene-level `notes` object is the slide default. A step's `notes`
follows the presenter's merge rule: its `text` replaces the scene text
while that step is active, and its `highlights` append to the scene's.

## The engine ignores both

fluvie stores `steps` and `notes`, validates them, and round-trips them.
It never reads them while rendering. A rendered video plays straight
through. Only `package:fluvie_presenter` interprets them: `deckFromSpec`
wraps each step's built children in a `Stop` and injects `SpeakerNotes`.
Only the editor authors them. fluvie never imports the presenter.

## The digest counts everything except `editor`

`VideoSpec.digest()` hashes the canonical JSON with exactly one key
removed: the top-level `editor` block. Everything else counts, including
`steps` and `notes`.

The line is drawn by audience, not by pixels. Steps and notes change what
an audience can be shown: a presented deck pauses differently, and a
speaker says different things. Two specs that differ there are different
documents, so they must not share a digest. The `editor` block is
authoring convenience only (viewport, panel state, names). It can never
change any output, so it must never invalidate a frame cache.

Two consequences are worth naming:

- A frame cache keyed by the digest re-renders when steps or notes
  change, even though the pixels did not. That is the accepted cost.
  One conservative digest beats a second digest flavor, and step edits
  are rare next to canvas edits, which change pixels anyway.
- Anything added to the spec later counts into the digest by default.
  Exclusion is the exception, and it needs this page amended first.

## Validation splits by what each layer can know

`spec_validation` checks shape and references per scene: `steps` is a
list of objects, every id in `elements` names a child of that scene, no
id repeats across steps, and `notes` carries only `text` (a string) and
`highlights` (a list of strings).

The presenter's `validateStepPlan` adds the compile-level checks the pure
validator cannot know: cross-element or beat triggers on an element
inside a step, and a timeline that does not resolve on its own. The
editor calls it live at edit time.

## Where to next

- [Authoring with specs](../guides/authoring-with-specs.md)
- [Timing and triggers](../guides/timing-and-triggers.md)
