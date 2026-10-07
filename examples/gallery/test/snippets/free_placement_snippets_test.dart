// The free-placement doc snippets compile and build (the page pulls them via
// code-excerpt markers), so a failing build here means the guide would ship
// dead code.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Placed, Placement;
import 'package:fluvie_example/snippets/free_placement_snippets.dart';

void main() {
  test('the free-placement video builds one canvas scene of placed elements', () {
    final video = freePlacementVideo();
    expect(video.scenes, hasLength(1));
    expect(video.totalFrames, greaterThan(0));
  });

  test('the placed title carries a sized fractional placement', () {
    final placed = placedTitle();
    expect(placed, isA<Placed>());
    final placement = (placed as Placed).placement;
    expect(placement.x, 0.5);
    expect(placement.width, isNotNull);
  });

  test('the rotated badge keeps its intrinsic size', () {
    final placement = (rotatedBadge() as Placed).placement;
    expect(placement.rotation, isNot(0));
    expect(placement.isIntrinsic, isTrue);
  });

  test('the placement round-trips through the spec transform', () {
    const placement = Placement(x: 0.5, y: 0.3, width: 0.8, height: 0.2);
    expect(placementAsTransformJson(placement), {
      'x': 0.5,
      'y': 0.3,
      'w': 0.8,
      'h': 0.2,
    });
  });
}
