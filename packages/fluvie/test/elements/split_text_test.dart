import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/rendering/primitives/fade_box.dart';

void main() {
  test('split tables preserve words, whitespace, newlines and grapheme clusters', () {
    expect(splitTextParts('', TextSplit.word), isEmpty);
    expect(splitTextParts('a', TextSplit.character), ['a']);
    expect(splitTextParts('a  b ', TextSplit.word), ['a  ', 'b ']);
    expect(splitTextParts(' a\nb\n', TextSplit.word), [' ', 'a', '\n', 'b', '\n']);
    expect(splitTextParts('a\nb\n', TextSplit.line), ['a', 'b', '']);
    expect(splitTextParts('e\u0301👨‍👩‍👧‍👦🇦🇹', TextSplit.character), [
      'e\u0301',
      '👨‍👩‍👧‍👦',
      '🇦🇹',
    ]);
    expect(splitTextParts('a\r\nb', TextSplit.line), ['a', 'b']);
  });
  testWidgets('the existing stagger distributor applies independent per-word offsets', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RenderControllerScope(
          controller: RenderController(initialFrame: 8),
          child: Video(
            width: 320,
            height: 180,
            scenes: [
              Scene(
                duration: const Time.frames(60),
                children: [
                  SplitText('One Two Three').effects([Effect.grade(exposure: 0.3)]).animate([
                    Animation.fadeIn(
                      duration: const Time.frames(20),
                      stagger: const Stagger.each(Time.frames(4)),
                      ease: Ease.linear,
                    ),
                  ]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    for (final (text, opacity) in [('One ', 0.4), ('Two ', 0.2), ('Three', 0.0)]) {
      final fades = find.ancestor(of: find.text(text), matching: find.byType(FadeBox));
      expect(tester.widget<FadeBox>(fades.first).opacity, closeTo(opacity, 1e-9));
    }
  });
}
