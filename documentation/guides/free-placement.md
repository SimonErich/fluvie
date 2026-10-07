# Free placement

Rows and columns are fine until a design wants the title exactly there.
`Placed` positions an element on the scene canvas by fractions, the same
geometry the visual editor writes, so a hand-authored layout and a
canvas-drawn one are the same thing.

<!-- code-excerpt "examples/gallery/lib/snippets/free_placement_snippets.dart (placed-title)" -->
```dart
Widget placedTitle() {
  return const Placed(
    placement: Placement(x: 0.5, y: 0.3, width: 0.8, height: 0.2),
    child: FittedBox(
      child: Text(
        'Placed exactly',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    ),
  );
}
```

`x` and `y` locate the element's anchor point as fractions of the canvas,
0 to 1. `width` and `height` size it the same way. Here the title's center
sits half way across and 30% down, in a box 80% wide and 20% tall,
whatever resolution the video renders at.

## A whole scene, placed

Give the scene several `Placed` children and the fractions alone decide
the layout. No layout widget mediates:

<!-- code-excerpt "examples/gallery/lib/snippets/free_placement_snippets.dart (video)" -->
```dart
Video freePlacementVideo() {
  return Video(
    size: VideoSize.hd,
    scenes: [
      Scene(
        duration: 4.seconds,
        background: Background.color(const Color(0xFF14141C)),
        children: [
          placedTitle(),
          placedPanel(),
          rotatedBadge(),
        ],
      ),
    ],
  );
}
```

A placed element animates like any other:

<!-- code-excerpt "examples/gallery/lib/snippets/free_placement_snippets.dart (placed-panel)" -->
```dart
Widget placedPanel() {
  return Placed(
    placement: const Placement(x: 0.3, y: 0.65, width: 0.34, height: 0.3),
    child: Container(color: const Color(0xFF6C5CE7)),
  ).animate([Animation.slideIn()]);
}
```

## Intrinsic size and rotation

Leave `width` and `height` off and the child keeps its own size; the
anchor point (the center, by default) lands on the placement point.
`rotation` turns the element around its center after layout, in degrees:

<!-- code-excerpt "examples/gallery/lib/snippets/free_placement_snippets.dart (rotated-badge)" -->
```dart
Widget rotatedBadge() {
  return const Placed(
    placement: Placement(x: 0.72, y: 0.62, rotation: -12),
    child: Text('NEW', style: TextStyle(color: Color(0xFF2ECC8F), fontSize: 40)),
  );
}
```

## The spec's transform key

A `Placement` is exactly the spec's `transform`. Encode one and you get
the JSON the editor writes when you drag:

<!-- code-excerpt "examples/gallery/lib/snippets/free_placement_snippets.dart (transform-json)" -->
```dart
Map<String, Object?> placementAsTransformJson(Placement placement) {
  return encodePlacement(placement);
}
```

```json
{ "x": 0.5, "y": 0.3, "w": 0.8, "h": 0.2 }
```

That symmetry is the point: draw a deck in the
[visual editor](../editor/editor-getting-started.md) and read it back as
data, or author the data and drag it around on the canvas.

## Where to next

- [Layouts](layouts.md): the flow layouts for when fractions are overkill.
- [The canvas](../editor/editor-canvas.md): the same geometry with a gizmo
  on it.
- [Authoring with specs](authoring-with-specs.md): the JSON side of the
  document.
