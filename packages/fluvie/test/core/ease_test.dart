import 'package:flutter/animation.dart' show Curves;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/ease.dart';

void main() {
  group('Ease', () {
    test('every member is the documented Flutter curve identity', () {
      expect(Ease.linear, same(Curves.linear));
      expect(Ease.smooth, same(Curves.easeInOut));
      expect(Ease.snappy, same(Curves.easeOutCubic));
      expect(Ease.gentle, same(Curves.easeInOutSine));
      expect(Ease.in_, same(Curves.easeIn));
      expect(Ease.out, same(Curves.easeOut));
      expect(Ease.inOut, same(Curves.easeInOut));
      expect(Ease.back, same(Curves.easeOutBack));
      expect(Ease.bounce, same(Curves.bounceOut));
      expect(Ease.elastic, same(Curves.elasticOut));
    });

    test('smooth (the package default) is the same curve as inOut', () {
      expect(Ease.smooth, same(Ease.inOut));
    });
  });
}
