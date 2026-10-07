# ADR: the video-mode document shape

Status: accepted, 2026-07-23.

This page fixes the `.fluvie` shape for audio tracks, element time windows,
and imported media. Video mode edits the same document as slides mode; these
three shapes are what it adds. The format version and its migration hook
absorb any later change.

## The decision in one look

```json
{
  "fps": 30,
  "audio": [
    {
      "kind": "music",
      "source": { "kind": "file", "value": "/home/ada/music/bed.mp3" },
      "volume": 0.8,
      "fadeIn": "1s",
      "fadeOut": "2s",
      "loop": true
    }
  ],
  "scenes": [
    {
      "duration": "12s",
      "audio": [
        {
          "kind": "sfx",
          "source": { "kind": "asset", "value": "audio/whoosh.mp3" },
          "at": "sceneStart"
        }
      ],
      "children": [
        {
          "id": "el-broll",
          "type": "Clip",
          "source": { "kind": "bundle", "value": "media/b-roll.mp4" },
          "show": { "from": "2s", "to": "6.5s" }
        }
      ]
    }
  ]
}
```

## Audio is a track list, mirrored from the constructors

A video may carry a top-level `audio` list, and each scene an `audio` list of
its own. Each entry is one track:

- `kind` (required): `music` or `sfx`, selecting `Audio.music` or `Audio.sfx`.
- `source` (required): the same `{kind, value}` object images and clips use.
- `volume`: linear gain, `1` plays the file as authored.
- Music only: `fadeIn` and `fadeOut` (times), `loop` (a bool), `trim` (a
  `{from, to}` object of times, the same shape as a clip's trim), and `track`
  (an anchor id naming the beat grid that `beat` triggers resolve against).
- Sfx only: `at`, a trigger in the same vocabulary animations use. Missing
  means the owner's start.

The field list is the constructors' field list, nothing more. `track` is in
even though a timeline lane never edits it, because the constructor carries
it and a beat trigger cannot serialize without it. Validation rejects a
music-only key on an sfx track and `at` on a music track: the constructors
force exactly those fields, and a silently dropped key would lie.

Placement in time comes from the owner, exactly as in the runtime. A
video-level track spans the video; a scene-level track starts with its scene.
There is no music `at` because `Audio.music` has none: to start a bed later,
put it on a later scene or trim it.

Unlike steps and notes, the engine consumes audio. The spec build hands the
video-level list to `Video.audio` and each scene's list to `Scene.audio`, and
the existing collector reads them from there in declaration order, video
first, then scenes. The per-track filter nodes and the `amix` graph do not
change. The digest counts audio, per the default rule: everything except
`editor` counts.

## `show` is a first-class element key

The runtime's `show({from, to})` is not an animation. It desugars to
`animate([], window: from.to(to))`: a `TimeRange` on the `.animate(...)` call
that overrides the element's alive window. The serialized animate entry has
three forms (preset, keyframes, raw from/to), and none carries a window,
because the window is an argument of the call and the `animate` list has no
slot for call-level arguments. A `fadeIn` plus `fadeOut` pair is not the same
thing either: the element stays mounted for the whole scene and its triggers
still resolve against the whole-scene window. Reuse would not produce the
same resolved spans, so `show` becomes a reserved element key:

- `from`: when the element becomes alive; missing means the scene start.
- `to`: when it stops; missing means the scene end.

An empty `show` object is invalid. `show()` with no bounds changes nothing in
the runtime, so save canonicalization removes the key instead, following the
no-residue rule the notes editor set.

The builder applies `show` as the `window` argument of the one `.animate(...)`
call it already makes for the element. One `MotionTarget`, so the element's
animations resolve inside the window: a clip that enters at `2s` plays its
`fadeIn` at `2s`. The `.show()` sugar is the no-animations special case of
exactly this call.

The law for tools: the timeline's lane edits write exactly this form.
Dragging a clip along its lane rewrites `from` and `to`. Dragging an edge
rewrites one of them. Resetting the lane removes the key.

## Media survives save and reload by kind

### Desktop keeps paths

The importer already writes `{ "kind": "file", "value": "/abs/path" }`, and
that stays the saved form. A save option rewrites file values that sit under
the document's directory to document-relative values, for decks that travel
with their media. The loader resolves a relative `file` value against the
document's directory before the spec reaches the engine, so the engine keeps
its plain path semantics.

### Web bytes ride a bundle

Bytes cannot live in the JSON: the media codec rejects memory sources by
design, and that stays. On the web an import becomes an in-memory source with
an object URL for live preview. Both are session state, not document state.

Save decides by content. A document that references no session media saves as
plain JSON, exactly as today. A document that does saves as a bundle: a zip
holding `deck.fluvie.json` plus a `media/` folder with the imported files.
Inside a bundle, a media or audio source uses a fourth kind:

```json
{ "kind": "bundle", "value": "media/b-roll.mp4" }
```

The value is bundle-relative, so the digest is stable across machines. A temp
unpack path in the JSON would re-key every frame cache per session. The
schema and validator learn the `bundle` kind because it is part of the
document format, but building a spec that still contains one throws, naming
the missing bundle context: the loader resolves each bundle source before
build, into memory sources on the web and into files under a sandboxed temp
directory on desktop, so the engine never sees the kind.

Saving plain JSON while session media exists warns, suppressibly, that the
media will not travel. Nothing is silently dropped or rewritten; the warning
is the whole intervention, per the additive-optional law.

Data URIs are rejected. Base64 grows every asset by a third inside a document
the editor holds, diffs, and autosaves as text. The digest hashes the
canonical JSON, so embedded megabytes would be rehashed on every dirty check.
And no honest line separates a small asset from a large one, so the cliff
would surface in production instead of review.

### One extension, sniffed

Both forms are `.fluvie`. A loader sniffs the leading bytes: `PK` (the zip
magic) means bundle, anything else parses as JSON. One extension keeps every
existing association, recent-files list, and docs page true. A second
extension would fork the format's identity to answer a question the first
two bytes already answer.

## The security boundary holds

- `FileSource` stays blocked at every media loader on untrusted render paths.
  Nothing here loosens that: a bundle never uses a `file` source for its own
  media, and imported web bytes travel as memory sources, never paths.
- Bundle unpacking is sandboxed. Entries are read only from `media/` plus the
  one deck JSON, entry names must be relative with no `..` segments (the
  zip-slip check), and per-entry plus total sizes are bounded before
  inflation.
- The web media store bounds the total bytes it holds and refuses an import
  past the budget with a visible error.
- The network allowlist is untouched; a bundle adds no fetch.
- Memory sources still have no plain-JSON form, so an untrusted spec cannot
  smuggle bytes. A `bundle` source outside a real bundle fails at build.

## Consequences and validation

- `AudioSource` has no memory variant today; the web path needs
  `AudioSource.memory` so imported audio reaches the mix without a path. That
  lands with the video-mode epics, alongside the audio serialization.
- Validation splits as before. The pure validator checks shape: track kinds,
  the source object, music/sfx key ownership, times and triggers that parse,
  a `track` id that resolves through the anchor table, and a `show` with at
  least one bound.
- The digest names sources; it does not hash media bytes. Replacing a file's
  contents under an unchanged name does not move the digest, which matches
  the advisory nature of the media cache.
- Opening a bundle and then saving plain JSON warns the same way session
  media does: the document would reference media the JSON cannot carry.

## Where to next

- [ADR: steps, notes, digest](steps-notes-digest.md)
- [Authoring with specs](../guides/authoring-with-specs.md)
- [Untrusted render security](untrusted-render-security.md)
