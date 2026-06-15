import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';

/// A leaf that hands its [BuildContext] to [onBuild] so tests can call the
/// static readers exactly where a descendant widget would.
Widget _probe(void Function(BuildContext context) onBuild) => Builder(
  builder: (context) {
    onBuild(context);
    return const SizedBox.shrink();
  },
);

void main() {
  group('FrameProvider', () {
    testWidgets('of returns the nearest provider when nested', (tester) async {
      late int seen;
      await tester.pumpWidget(
        FrameProvider(
          frame: 3,
          child: FrameProvider(
            frame: 9,
            child: _probe((context) => seen = FrameProvider.of(context).frame),
          ),
        ),
      );
      expect(seen, 9);
    });

    testWidgets('maybeOf returns null without a provider above', (tester) async {
      FrameProvider? seen;
      var probed = false;
      await tester.pumpWidget(
        _probe((context) {
          seen = FrameProvider.maybeOf(context);
          probed = true;
        }),
      );
      expect(probed, isTrue);
      expect(seen, isNull);
    });

    testWidgets('of throws a FluvieTimingError naming FrameProvider when absent', (tester) async {
      await tester.pumpWidget(_probe(FrameProvider.of));
      final exception = tester.takeException();
      expect(exception, isA<FluvieTimingError>());
      expect(exception.toString(), contains('FrameProvider'));
    });

    test('updateShouldNotify fires only when the frame changes', () {
      const child = SizedBox.shrink();
      const old = FrameProvider(frame: 5, child: child);
      const same = FrameProvider(frame: 5, child: child);
      const changed = FrameProvider(frame: 6, child: child);
      expect(same.updateShouldNotify(old), isFalse);
      expect(changed.updateShouldNotify(old), isTrue);
    });
  });
}
