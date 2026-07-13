import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

void main() {
  test('HiddenStop values are equal and hash alike', () {
    expect(const HiddenStop(), const HiddenStop());
    expect(const HiddenStop().hashCode, const HiddenStop().hashCode);
    expect(const HiddenStop(), isNot(const RevealedStop(baseFrame: 0)));
  });

  test('RevealedStop compares by base and skip', () {
    expect(
      const RevealedStop(baseFrame: 10, skipFrames: 5),
      const RevealedStop(baseFrame: 10, skipFrames: 5),
    );
    expect(
      const RevealedStop(baseFrame: 10, skipFrames: 5).hashCode,
      const RevealedStop(baseFrame: 10, skipFrames: 5).hashCode,
    );
    expect(
      const RevealedStop(baseFrame: 10),
      isNot(const RevealedStop(baseFrame: 11)),
    );
    expect(
      const RevealedStop(baseFrame: 10),
      isNot(const RevealedStop(baseFrame: 10, skipFrames: 1)),
    );
  });

  test('RevealedStop prints its rebasing', () {
    expect(
      const RevealedStop(baseFrame: 10, skipFrames: 5).toString(),
      'RevealedStop(base: 10, skip: 5)',
    );
  });
}
