// Compiled, tested snippets for documentation/guides/free-placement.md.
// Each `#docregion` flows into one fence via a `<!-- code-excerpt -->`
// marker, so the guide can never drift from the real placement API.

import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

/// One canvas scene laid out by fractions instead of rows and columns.
// #docregion video
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
// #enddocregion video

/// A sized placement: the title band fills 80% of the width, 20% of the
/// height, centered at 30% down the canvas.
// #docregion placed-title
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
// #enddocregion placed-title

/// A second sized placement next to the first — no layout widget mediates,
/// the fractions alone decide where things sit.
// #docregion placed-panel
Widget placedPanel() {
  return Placed(
    placement: const Placement(x: 0.3, y: 0.65, width: 0.34, height: 0.3),
    child: Container(color: const Color(0xFF6C5CE7)),
  ).animate([Animation.slideIn()]);
}
// #enddocregion placed-panel

/// An intrinsic placement: no width or height, so the child keeps its own
/// size and the anchor point lands on the placement point. Rotation turns
/// the element around its center after layout.
// #docregion rotated-badge
Widget rotatedBadge() {
  return const Placed(
    placement: Placement(x: 0.72, y: 0.62, rotation: -12),
    child: Text('NEW', style: TextStyle(color: Color(0xFF2ECC8F), fontSize: 40)),
  );
}
// #enddocregion rotated-badge

/// The same geometry as spec data: a [Placement] is the `transform` key.
// #docregion transform-json
Map<String, Object?> placementAsTransformJson(Placement placement) {
  return encodePlacement(placement);
}

// #enddocregion transform-json
