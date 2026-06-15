import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the package skeleton builds a widget tree', (tester) async {
    await tester.pumpWidget(const Placeholder());

    expect(find.byType(Placeholder), findsOneWidget);
  });
}
