// WI-10 (D-Mermaid staged reveal): the sealed MermaidReveal value type + the
// pure mermaidRevealOpacity resolver. none -> always full; the timed variants
// ramp 0 -> 1 over their window by delegating to revealProgress (which resolves
// the Time against the scope). Pure frame arithmetic, no mounting.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/mermaid/mermaid_reveal.dart';
import 'package:fluvie/src/elements/reveal/reveal_progress.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

const _scope = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 60);

// A runtime frame count: defeats const-canonicalization so two constructions
// are distinct instances, making "equal value implies equal hashCode" a real,
// failable check rather than a comparison of one canonical object to itself.
int _rt(int n) => int.parse('$n');

void main() {
  group('MermaidReveal variants', () {
    test('none is the const singleton', () {
      expect(identical(MermaidReveal.none, MermaidReveal.none), isTrue);
      expect(MermaidReveal.none, MermaidReveal.none);
      // none hashes distinctly from a timed variant: exercises its hashCode
      // with an assertion that can actually fail on a cross-variant collision.
      expect(
        MermaidReveal.none.hashCode,
        isNot(MermaidReveal.fadeNodes(Time.frames(_rt(30))).hashCode),
      );
    });

    test('fadeNodes is value-equal by its window', () {
      final a = MermaidReveal.fadeNodes(Time.frames(_rt(30)));
      final b = MermaidReveal.fadeNodes(Time.frames(_rt(30)));
      expect(identical(a, b), isFalse, reason: 'distinct runtime instances');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(MermaidReveal.fadeNodes(Time.frames(_rt(15)))));
    });

    test('drawEdges is value-equal by its window', () {
      final a = MermaidReveal.drawEdges(Time.frames(_rt(30)));
      final b = MermaidReveal.drawEdges(Time.frames(_rt(30)));
      expect(identical(a, b), isFalse, reason: 'distinct runtime instances');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(MermaidReveal.drawEdges(Time.frames(_rt(15)))));
    });

    test('a different window differs', () {
      expect(
        const MermaidReveal.fadeNodes(Time.frames(30)),
        isNot(const MermaidReveal.fadeNodes(Time.frames(20))),
      );
    });

    test('the variants are distinct from each other and from none', () {
      expect(const MermaidReveal.fadeNodes(Time.frames(30)), isNot(MermaidReveal.none));
      expect(
        const MermaidReveal.fadeNodes(Time.frames(30)),
        isNot(const MermaidReveal.drawEdges(Time.frames(30))),
      );
    });

    test('toString names each variant', () {
      expect(MermaidReveal.none.toString(), contains('none'));
      expect(const MermaidReveal.fadeNodes(Time.frames(30)).toString(), contains('fadeNodes'));
      expect(const MermaidReveal.drawEdges(Time.frames(30)).toString(), contains('drawEdges'));
    });
  });

  group('mermaidRevealOpacity', () {
    test('none is always full opacity', () {
      expect(mermaidRevealOpacity(MermaidReveal.none, 0, _scope), 1.0);
      expect(mermaidRevealOpacity(MermaidReveal.none, 99, _scope), 1.0);
    });

    test('fadeNodes ramps 0 -> 1 across its window', () {
      const reveal = MermaidReveal.fadeNodes(Time.frames(30));
      expect(mermaidRevealOpacity(reveal, 0, _scope), 0.0);
      expect(mermaidRevealOpacity(reveal, 15, _scope), closeTo(0.5, 1e-9));
      expect(mermaidRevealOpacity(reveal, 30, _scope), 1.0);
      expect(mermaidRevealOpacity(reveal, 45, _scope), 1.0); // clamped
    });

    test('drawEdges ramps 0 -> 1 across its window', () {
      const reveal = MermaidReveal.drawEdges(Time.frames(20));
      expect(mermaidRevealOpacity(reveal, 0, _scope), 0.0);
      expect(mermaidRevealOpacity(reveal, 10, _scope), closeTo(0.5, 1e-9));
      expect(mermaidRevealOpacity(reveal, 20, _scope), 1.0);
    });

    test('delegates to revealProgress (resolves Time against the scope)', () {
      const reveal = MermaidReveal.fadeNodes(Time.frames(30));
      for (final frame in [0, 7, 15, 23, 30]) {
        expect(
          mermaidRevealOpacity(reveal, frame, _scope),
          revealProgress(frame, _scope, const Time.frames(30)),
        );
      }
    });

    test('a relative window resolves against the scope duration', () {
      // 0.5.relative over a 60-frame scope -> 30 frames.
      const reveal = MermaidReveal.fadeNodes(Time.relative(0.5));
      expect(mermaidRevealOpacity(reveal, 15, _scope), closeTo(0.5, 1e-9));
      expect(mermaidRevealOpacity(reveal, 30, _scope), 1.0);
    });
  });
}
