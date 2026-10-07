import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/serialization/codecs/transition_codec.dart';

final class _Strategy implements TransitionStrategy {
  int calls = 0;
  @override
  List<Widget> compose({
    required Widget outgoing,
    required Widget incoming,
    required double easedProgress,
    required Transition spec,
  }) {
    calls++;
    return [outgoing, incoming];
  }
}

void main() {
  test('custom transition registry and codec preserve its name and parameters', () {
    final strategy = _Strategy();
    registerTransitionStrategy('customSpin', strategy);
    addTearDown(() => unregisterTransitionStrategy('customSpin'));
    const transition = Transition.custom('customSpin', Time.frames(12), parameters: {'turns': 2});
    final json = encodeTransition(transition);
    expect(json['kind'], 'customSpin');
    expect(json['turns'], 2);
    final read = decodeTransition(json);
    expect(read.customKind, 'customSpin');
    expect(strategyFor(read.customKind!), same(strategy));
  });
  test('cut cannot be registered as a blend', () {
    expect(() => registerTransitionStrategy('cut', _Strategy()), throwsArgumentError);
    expect(() => strategyFor(TransitionKind.cut), throwsArgumentError);
  });
  testWidgets('a registered custom kind reaches the live compositor', (tester) async {
    final strategy = _Strategy();
    registerTransitionStrategy('pluginBlend', strategy);
    addTearDown(() => unregisterTransitionStrategy('pluginBlend'));
    final controller = RenderController(initialFrame: 15);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 100,
          height: 100,
          child: RenderControllerScope(
            controller: controller,
            child: Video(
              width: 100,
              height: 100,
              transition: const Transition.custom('pluginBlend', Time.frames(10)),
              scenes: const [
                Scene(duration: Time.frames(20), children: [SizedBox.expand()]),
                Scene(duration: Time.frames(20), children: [SizedBox.expand()]),
              ],
            ),
          ),
        ),
      ),
    );
    expect(strategy.calls, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
