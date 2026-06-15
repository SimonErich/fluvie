// WI-19 (D13): `LabelRef` is a value naming a Timeline label plus an offset, and
// `String.label` is the call-site sugar. `'reveal'.label` is the label at zero
// offset; `+`/`-` carry signed offsets; instances are value-equal.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/timeline_label.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// A 30fps scope so seconds-valued offsets resolve to a concrete frame count.
const _scope = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 300);

void main() {
  group('String.label', () {
    test('builds a LabelRef at zero offset', () {
      final ref = 'reveal'.label;
      expect(ref.name, 'reveal');
      expect(ref.offset, Time.zero);
    });
  });

  group('LabelRef arithmetic', () {
    test('+ carries a positive offset', () {
      final ref = 'reveal'.label + 0.2.seconds;
      expect(ref.name, 'reveal');
      expect(ref.offset.resolveFrames(_scope), 6); // 0.2s @ 30fps
    });

    test('- carries a negative offset', () {
      final ref = 'reveal'.label - 0.2.seconds;
      expect(ref.name, 'reveal');
      expect(ref.offset.resolveFrames(_scope), -6);
    });

    test('chained arithmetic accumulates the offset', () {
      final ref = 'reveal'.label + 0.5.seconds - 0.2.seconds;
      expect(ref.name, 'reveal');
      expect(ref.offset.resolveFrames(_scope), 9); // (0.5 - 0.2)s @ 30fps
    });
  });

  group('LabelRef value equality', () {
    test('same name and offset are equal', () {
      expect('reveal'.label, 'reveal'.label);
      expect('reveal'.label.hashCode, 'reveal'.label.hashCode);
    });

    test('different name is unequal', () {
      expect('reveal'.label == 'hide'.label, isFalse);
    });

    test('different offset is unequal', () {
      expect('reveal'.label + 0.1.seconds == 'reveal'.label, isFalse);
    });

    test('toString names the label and offset', () {
      expect('reveal'.label.toString(), contains('reveal'));
    });
  });
}
