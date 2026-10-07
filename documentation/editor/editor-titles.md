# Titles and motion

Open **Titles** beside Assets, choose a full-screen headline, lower third, credits or callout, then edit its selected text on the canvas or in the inspector. A title inserts ordinary elements on the active lane at the playhead, bounded by the scene end. It adds missing theme tokens and master definitions; existing document tokens win. The complete insertion is one undo step. The four shipped compositions are JSON assets in `fluvie_editor/assets/titles`, so saved documents remain editable without a preset dependency.

`SplitText` splits by word, extended grapheme cluster, or explicit line. Combining accents and emoji sequences stay intact. Apply ordinary animation presets with `stagger`; each part uses the same stagger distributor and clock as a Row or Group. Effects and shared-element wrappers preserve this distribution.

Select an element and open **Animation** to edit an animation's easing, a keyframe segment, or a numeric effect segment. Drag a control point or enter its coordinates. A drag commits once on release, so undo restores the previous curve in one step. Choose a named ease to reset the curve. Custom curves serialize as `{"cubic": [x1, y1, x2, y2]}`; an exact named shape canonicalizes back to its name. X coordinates remain within `[0,1]`; Y coordinates may overshoot. The same cubic appears as a native Flutter `Cubic(...)` in exported Dart.

<!-- code-excerpt "examples/gallery/lib/snippets/spec_serialization_snippets.dart (title-motion)" -->
```dart
Widget titleMotion() =>
    SplitText(
      'Your next great story',
      style: const TextStyle(fontSize: 54, fontWeight: FontWeight.bold),
    ).animate([
      Animation.slideFadeIn(
        duration: const Time.frames(30),
        ease: const Cubic(0.2, 0.9, 0.6, 1),
        stagger: const Stagger.each(Time.frames(4)),
      ),
    ]);
```
