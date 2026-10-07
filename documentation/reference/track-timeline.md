# Configure a TrackTimeline

Run the public configuration and retained-callback examples from the repository
root:

```sh
cd packages/fluvie_editor
flutter test --no-pub test/widgets/track_timeline_configuration_test.dart test/widgets/track_timeline_retained_callbacks_test.dart
```

Read the [configuration example](../../packages/fluvie_editor/test/widgets/track_timeline_configuration_test.dart)
for the constructor types and defaults. The
[widget fixture](../../packages/fluvie_editor/test/widgets/fixtures/track_timeline_fixture.dart)
shows how you rebuild a timeline with new selection and callback values.

## Migrate the grouped inputs

`TrackTimeline` now takes six configuration objects instead of individual
selection, callback and appearance arguments. This is a breaking constructor
change. Import the objects from `package:fluvie_editor/fluvie_editor.dart`.

Move each old argument into its group. Read its value through the same group on
the widget. For example, `selectedTrackIds` becomes
`selection.selectedTrackIds`, and `onBarMoved` becomes `edit.onBarMoved`.

| Constructor argument | Configuration type | Inputs you put here |
| --- | --- | --- |
| `selection` | `TrackTimelineSelection` | Selected track, bar, diamond, link and marker IDs; selected frame range. |
| `navigation` | `TrackTimelineNavigation` | Scrub, label, range, bar, marquee and track-selection callbacks. |
| `edit` | `TrackTimelineEditActions` | Bar move, resize and easing callbacks; foreign drops; drag start and end. |
| `overlays` | `TrackTimelineOverlayActions` | Diamond, link and ruler-marker callbacks. |
| `lanes` | `TrackTimelineLaneActions` | Lane reorder, lock, mute and solo callbacks. |
| `appearance` | `TrackTimelineAppearance` | Empty-state message and action; label width, track height and ruler height. |

Keep these arguments directly on `TrackTimeline`: `tracks`, `fps`,
`totalFrames`, `playhead`, `controller`, `links`, `markers`, `snapFrame` and
`onFilmstripNeeded`. `tracks`, `fps` and `totalFrames` remain required.

## Keep ownership and defaults

You can omit any group. Each defaults to its empty const configuration.
Selection sets default to empty. Callbacks default to null. Appearance keeps
the message `Nothing here yet.`, a label width of 140, a track height of 28 and a
ruler height of 24 logical pixels.

The groups do not wrap callbacks or copy your collections. You still own the
document and selection. The widget reports editing intentions; your host
applies them and rebuilds with updated values. Callback signatures, including
the required named `additive` argument, are unchanged.

Reuse your `TrackTimelineController` across selection rebuilds to retain zoom
and collapsed groups. Replacing the controller detaches the old listener.
The timeline creates and disposes its own controller when you omit one; you
remain responsible for disposing a controller you supply.

## Where to next

- [The timeline](../editor/editor-timeline.md): the editing interactions.
- [Timing and triggers](../guides/timing-and-triggers.md): the timing model.
- [Retained-callback examples](../../packages/fluvie_editor/test/widgets/track_timeline_retained_callbacks_test.dart): rebuild, focus and controller contracts.
