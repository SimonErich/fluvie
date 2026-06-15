import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/camera/camera.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';

void main() {
  group('Camera.poseAt endpoints', () {
    test('still is the identity pose at every q', () {
      const camera = Camera.still();
      for (final q in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final pose = camera.poseAt(q);
        expect(pose.scale, 1.0);
        expect(pose.focal, Alignment.center);
      }
    });

    test('push lerps scale 1 -> zoom about the fixed toward alignment', () {
      const camera = Camera.push(zoom: 2, toward: Alignment.topRight);
      expect(camera.poseAt(0).scale, 1.0);
      expect(camera.poseAt(0.5).scale, 1.5);
      expect(camera.poseAt(1).scale, 2.0);
      // The focal point never moves on a push.
      expect(camera.poseAt(0).focal, Alignment.topRight);
      expect(camera.poseAt(0.5).focal, Alignment.topRight);
      expect(camera.poseAt(1).focal, Alignment.topRight);
    });

    test('pull lerps scale zoom -> 1 about the fixed from alignment', () {
      const camera = Camera.pull(zoom: 2, from: Alignment.bottomLeft);
      expect(camera.poseAt(0).scale, 2.0);
      expect(camera.poseAt(0.5).scale, 1.5);
      expect(camera.poseAt(1).scale, 1.0);
      expect(camera.poseAt(0).focal, Alignment.bottomLeft);
      expect(camera.poseAt(1).focal, Alignment.bottomLeft);
    });

    test('pan holds a constant zoom and lerps the focal from -> to', () {
      const camera = Camera.pan(
        from: Alignment.topLeft,
        to: Alignment.bottomRight,
        zoom: 1.5,
      );
      expect(camera.poseAt(0).scale, 1.5);
      expect(camera.poseAt(0.5).scale, 1.5);
      expect(camera.poseAt(1).scale, 1.5);
      expect(camera.poseAt(0).focal, Alignment.topLeft);
      expect(camera.poseAt(0.5).focal, Alignment.center);
      expect(camera.poseAt(1).focal, Alignment.bottomRight);
    });
  });

  group('Camera defaults', () {
    test('push carries the golden-pinned micro-defaults', () {
      const camera = Camera.push();
      expect(camera.poseAt(1).scale, 1.2);
      expect(camera.poseAt(1).focal, Alignment.center);
      expect(camera.over, const Time.relative(1));
      expect(camera.ease, Ease.linear);
    });

    test('pull and pan carry the same over/ease defaults', () {
      const pull = Camera.pull();
      const pan = Camera.pan(from: Alignment.topLeft, to: Alignment.topRight);
      expect(pull.over, const Time.relative(1));
      expect(pull.ease, Ease.linear);
      expect(pan.over, const Time.relative(1));
      expect(pan.ease, Ease.linear);
    });
  });

  group('Camera value equality', () {
    test('still cameras are equal and share a hash', () {
      expect(const Camera.still(), const Camera.still());
      expect(const Camera.still().hashCode, const Camera.still().hashCode);
    });

    test('same-field pushes are equal; a differing field breaks it', () {
      expect(
        const Camera.push(zoom: 1.5, toward: Alignment.topLeft),
        const Camera.push(zoom: 1.5, toward: Alignment.topLeft),
      );
      expect(
        const Camera.push(zoom: 1.5),
        isNot(const Camera.push(zoom: 1.6)),
      );
      expect(
        const Camera.push(toward: Alignment.topLeft),
        isNot(const Camera.push(toward: Alignment.topRight)),
      );
      expect(
        const Camera.push(over: Time.relative(0.5)),
        isNot(const Camera.push()),
      );
      expect(
        const Camera.push(ease: Ease.smooth),
        isNot(const Camera.push()),
      );
    });

    test('distinct kinds are never equal even with matching fields', () {
      expect(const Camera.push(zoom: 1.5), isNot(const Camera.pull(zoom: 1.5)));
      expect(const Camera.still(), isNot(const Camera.push()));
    });

    test('pan equality covers both alignments', () {
      expect(
        const Camera.pan(from: Alignment.topLeft, to: Alignment.topRight),
        const Camera.pan(from: Alignment.topLeft, to: Alignment.topRight),
      );
      expect(
        const Camera.pan(from: Alignment.topLeft, to: Alignment.topRight),
        isNot(const Camera.pan(from: Alignment.topLeft, to: Alignment.bottomRight)),
      );
    });

    test('toString is stable per kind', () {
      expect(const Camera.still().toString(), 'Camera.still()');
      expect(const Camera.push().toString(), contains('Camera.push'));
      expect(const Camera.pull(zoom: 1.5).toString(), contains('Camera.pull(zoom: 1.5'));
      expect(
        const Camera.pan(from: Alignment.topLeft, to: Alignment.topRight).toString(),
        contains('Camera.pan(from:'),
      );
    });
  });

  group('Camera asserts', () {
    test('a push zoom below 1 asserts', () {
      expect(() => Camera.push(zoom: 0.9), throwsA(isA<AssertionError>()));
    });

    test('a pull zoom below 1 asserts', () {
      expect(() => Camera.pull(zoom: 0.5), throwsA(isA<AssertionError>()));
    });

    test('a pan zoom below 1 asserts', () {
      expect(
        () => Camera.pan(from: Alignment.topLeft, to: Alignment.topRight, zoom: 0.99),
        throwsA(isA<AssertionError>()),
      );
    });

    test('zoom exactly 1 is allowed', () {
      expect(const Camera.push(zoom: 1).poseAt(1).scale, 1.0);
    });

    test('relative sugar resolves to the same default over', () {
      expect(const Camera.push().over, 1.0.relative);
    });
  });
}
