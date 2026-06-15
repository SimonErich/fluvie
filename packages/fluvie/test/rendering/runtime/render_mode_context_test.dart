import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

/// A leaf that hands its [BuildContext] to [onBuild] so tests can call the
/// static readers exactly where a descendant widget would.
Widget _probe(void Function(BuildContext context) onBuild) => Builder(
  builder: (context) {
    onBuild(context);
    return const SizedBox.shrink();
  },
);

void main() {
  group('RenderModeContext', () {
    testWidgets('modeOf defaults to preview when no context is above', (tester) async {
      late RenderMode seen;
      await tester.pumpWidget(_probe((context) => seen = RenderModeContext.modeOf(context)));
      expect(seen, RenderMode.preview);
    });

    testWidgets('capture mode is visible to descendants', (tester) async {
      late RenderMode seen;
      await tester.pumpWidget(
        RenderModeContext(
          mode: RenderMode.capture,
          child: _probe((context) => seen = RenderModeContext.modeOf(context)),
        ),
      );
      expect(seen, RenderMode.capture);
    });

    testWidgets('isCapture is true under capture and false under preview', (tester) async {
      late bool underCapture;
      await tester.pumpWidget(
        RenderModeContext(
          mode: RenderMode.capture,
          child: _probe((context) => underCapture = RenderModeContext.isCapture(context)),
        ),
      );
      expect(underCapture, isTrue);

      late bool underPreview;
      await tester.pumpWidget(
        RenderModeContext(
          mode: RenderMode.preview,
          child: _probe((context) => underPreview = RenderModeContext.isCapture(context)),
        ),
      );
      expect(underPreview, isFalse);
    });

    testWidgets('the nearest context wins when nested', (tester) async {
      late RenderMode seen;
      await tester.pumpWidget(
        RenderModeContext(
          mode: RenderMode.capture,
          child: RenderModeContext(
            mode: RenderMode.preview,
            child: _probe((context) => seen = RenderModeContext.modeOf(context)),
          ),
        ),
      );
      expect(seen, RenderMode.preview);
    });

    test('updateShouldNotify fires only when the mode changes', () {
      const child = SizedBox.shrink();
      const old = RenderModeContext(mode: RenderMode.capture, child: child);
      const same = RenderModeContext(mode: RenderMode.capture, child: child);
      const changed = RenderModeContext(mode: RenderMode.preview, child: child);
      expect(same.updateShouldNotify(old), isFalse);
      expect(changed.updateShouldNotify(old), isTrue);
    });
  });
}
