import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slides/slides_app.dart';

void main() {
  testWidgets('the shell boots to its placeholder stage', (tester) async {
    await tester.pumpWidget(const SlidesApp());
    expect(find.text('fluvie slides'), findsOneWidget);
    expect(find.byType(ColoredBox), findsOneWidget);
  });
}
