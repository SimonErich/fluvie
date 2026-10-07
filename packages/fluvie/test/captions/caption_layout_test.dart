import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/captions/runtime/caption_cue_view.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required CaptionPosition position,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  return tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox.fromSize(
          size: size,
          child: CaptionCueView(
            cue: CaptionCue('Milo plays', start: Time.zero, end: const Time.seconds(2)),
            frame: 0,
            scope: const TimeScopeData(fps: 30, startFrame: 0, durationFrames: 60),
            style: const CaptionStyle(
              textStyle: TextStyle(fontSize: 14),
              background: Color(0x80000000),
              highlight: Color(0xffffffff),
            ),
            position: position,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('custom placement can opt into adaptive insets', (tester) async {
    await _pump(
      tester,
      size: const Size(160, 160),
      position: const CaptionPosition.custom(
        Alignment.bottomCenter,
        safeArea: 64,
        adaptiveSafeArea: true,
      ),
    );
    expect(
      tester.widgetList<Padding>(find.byType(Padding)).first.padding,
      const EdgeInsets.all(160 / 12),
    );
  });

  test('adaptive placement participates in value identity', () {
    const exact = CaptionPosition.custom(Alignment(0, 1 / 3), safeArea: 64);
    const adaptive = CaptionPosition.bottomThird();
    expect(exact, isNot(adaptive));
    expect(exact.hashCode, isNot(adaptive.hashCode));
    expect(
      adaptive,
      const CaptionPosition.custom(Alignment(0, 1 / 3), safeArea: 64, adaptiveSafeArea: true),
    );
    expect(adaptive.toString(), contains('adaptiveSafeArea: true'));
  });

  for (final position in [
    const CaptionPosition.bottomThird(),
    const CaptionPosition.topThird(),
  ]) {
    testWidgets('preset keeps caption glyphs inside a small canvas ($position)', (tester) async {
      await _pump(tester, size: const Size(160, 160), position: position);
      final paragraph = tester.renderObject<RenderParagraph>(find.text('Milo plays'));
      final boxes = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 10),
      );
      expect(paragraph.size.width, greaterThan(90));
      expect(boxes, isNotEmpty);
      for (final box in boxes) {
        expect(box.left, greaterThanOrEqualTo(0));
        expect(box.right, lessThanOrEqualTo(paragraph.size.width));
        expect(box.bottom, lessThanOrEqualTo(paragraph.size.height));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('preset retains its 64 pixel inset on a regular video ($position)', (tester) async {
      await _pump(tester, size: const Size(1920, 1080), position: position);
      final padding = tester.widgetList<Padding>(find.byType(Padding)).first;
      expect(padding.padding, const EdgeInsets.all(64));
    });
  }

  testWidgets('explicit custom safe area remains exact on a small canvas', (tester) async {
    await _pump(
      tester,
      size: const Size(160, 160),
      position: const CaptionPosition.custom(Alignment.bottomCenter, safeArea: 16),
    );
    expect(
      tester.widgetList<Padding>(find.byType(Padding)).first.padding,
      const EdgeInsets.all(16),
    );
  });

  testWidgets('explicit custom placement can preserve the old preset inset', (tester) async {
    await _pump(
      tester,
      size: const Size(160, 160),
      position: const CaptionPosition.custom(Alignment(0, 1 / 3), safeArea: 64),
    );
    expect(
      tester.widgetList<Padding>(find.byType(Padding)).first.padding,
      const EdgeInsets.all(64),
    );
  });
}
