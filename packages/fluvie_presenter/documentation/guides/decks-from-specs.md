# Decks from specs

A deck can be a `.fluvie` JSON document. Load it, build it with
`deckFromSpec`, and present it:

<!-- code-excerpt "../../apps/slides/lib/snippets/presenter_snippets.dart (deck-from-spec)" -->
```dart
Widget presentSpec(String fluvieJson) {
  final spec = VideoSpec.fromJson(jsonDecode(fluvieJson) as Map<String, Object?>);
  return FluvieSlides(deckFromSpec(spec));
}
```

`deckFromSpec` builds the same `Video` that `buildVideo` does, then makes the
spec's presentation metadata real: each scene's `steps` entry becomes a
`Stop`, and every `notes` object becomes a `SpeakerNotes`. A step's stop sits
where the step's first element sat, and the elements inside keep the scene's
child order, so revealing content never restacks it. The `steps` list order
is the step order, whatever the elements' positions.

fluvie itself never reads `steps` or `notes`: render the same document and it
plays straight through. Only this package interprets them. The shapes are
fixed in the
[steps-and-notes ADR](https://github.com/SimonErich/fluvie/blob/main/documentation/contributing/steps-notes-digest.md).

Hand the *same* `Video` instance to `FluvieSlides` and to any
`compileSlidePlans`/`compileNotes` call you make yourself. The step machinery
keys stops by widget identity, so two builds of one spec do not mix.

## Check a deck without presenting it

Editing tools want problems as a list, not a throw. `validateStepPlan` runs
the compile-level checks (cross-element or beat triggers on stepped elements,
a timeline that does not resolve) plus the step reference checks, and returns
every problem it can collect:

<!-- code-excerpt "../../apps/slides/lib/snippets/presenter_snippets.dart (validate-step-plan)" -->
```dart
void reportStepProblems(VideoSpec spec) {
  for (final error in validateStepPlan(spec)) {
    debugPrint(error.message);
  }
}
```

An empty list means the deck presents. Reference problems (an id that names
no child, an id in two steps) collect across every scene at once; compile
problems collect one per broken scene.

## Where to next

- [Builds with Stop](../getting-started/builds-with-stop.md): the widget side
  of the same step model.
- [Speaker notes](../getting-started/speaker-notes.md): what the notes panel
  and speaker window show.
- [Present your first video](../getting-started/present-your-first-video.md):
  the five-line start.
