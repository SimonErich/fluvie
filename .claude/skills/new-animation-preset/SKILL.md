---
name: new-animation-preset
description: Add a Fluvie animation preset as thin sugar over Animation.from/to/keyframes (never new animation logic), with an Alchemist golden. Use when adding a named preset like slideFade, pop, blurIn, kenBurns.
---

# new-animation-preset

Presets are **guessable names that expand to the foundation** (`Animation.from` /
`to` / `fromTo` / `keyframes`). A preset must contain **no** animation logic the
core can't already express — if it needs something new, extend `Keyframe` or add
an `AnimationEffect`, not the preset (DRY).

## Steps

1. **Express it as foundation** — write the preset as a factory returning
   `Animation.from(...)` / `to(...)` / `keyframes(...)` with the right `Keyframe`
   (offsets are fractions of the element's own size; `Edge` gives the vector).
2. **Pick the timing default** — bouncy presets (`pop`, `scaleIn`) default to a
   `Spring`; others use `Ease.smooth`. Expose only the params that are real choices.
3. **Dartdoc** showing the expansion (e.g. `=> Animation.from(Keyframe(opacity: 0, ...))`).
4. **Golden** at 0/50/100% via `golden-frame`; confirm it matches the documented expansion.
5. **Gate** — `melos run gate` green; commit `feat(animation): add Animation.<name> preset`.

## Template

```dart
extension AnimationPresets on Animation {
  /// Slides in from [from] (one element-size away) while fading in.
  ///
  /// Expands to `Animation.from(Keyframe(opacity: 0, x: from.dx, y: from.dy))`.
  static Animation slideFade({Edge from = Edge.bottom, Time? duration}) {
    return Animation.from(
      Keyframe(opacity: 0, x: from.dx, y: from.dy),
      duration: duration,
    );
  }
}
```
