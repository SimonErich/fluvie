// DRY 2.2: the shared-element wrap helper extracted from the 8 elements that
// each copy-pasted `shared == null ? x : SharedElement(anchor: shared, child:
// x)`. Asserts the null-anchor branch returns the child unchanged (no
// SharedElement mounted) and the non-null branch wraps it in a SharedElement
// carrying the same anchor instance and child. Behavior-preserving: the helper
// keeps the null conditional rather than leaning on SharedElement's internal
// passthrough.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';

void main() {
  test('a null anchor returns the child unchanged (no SharedElement)', () {
    const child = SizedBox();
    expect(identical(wrapShared(null, child), child), isTrue);
  });

  test('a non-null anchor wraps the child in a SharedElement', () {
    final anchor = Anchor('logo');
    const child = SizedBox();
    final wrapped = wrapShared(anchor, child);
    expect(wrapped, isA<SharedElement>());
    final shared = wrapped as SharedElement;
    expect(identical(shared.anchor, anchor), isTrue);
    expect(identical(shared.child, child), isTrue);
  });

  test('distinct anchor instances produce distinct wrappers', () {
    const child = SizedBox();
    final a = wrapShared(Anchor('x'), child) as SharedElement;
    final b = wrapShared(Anchor('x'), child) as SharedElement;
    expect(identical(a.anchor, b.anchor), isFalse);
  });
}
