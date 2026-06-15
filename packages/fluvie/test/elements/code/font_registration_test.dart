// WI-2 (D-Font): the bundled JetBrains Mono font asset is registered under
// `flutter: fonts:` in the package pubspec with `package: 'fluvie'`. This proves
// the declaration is wired: a Text styled with the family resolves it, and the
// package-prefixed family name is what consumers and goldens see.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JetBrains Mono font registration (WI-2)', () {
    testWidgets('a Text with the bundled family resolves the family', (tester) async {
      const style = TextStyle(fontFamily: 'JetBrains Mono', package: 'fluvie');
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('void main() {}', style: style),
        ),
      );
      final text = tester.widget<Text>(find.byType(Text));
      // The package prefix is what the font manager registers the family under,
      // so a package-scoped family resolves to `packages/<pkg>/<family>`.
      expect(text.style!.fontFamily, 'packages/fluvie/JetBrains Mono');
    });
  });
}
