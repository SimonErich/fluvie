import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:slides/slides_app.dart';

void main() {
  testWidgets('the shell presents the demo deck live', (tester) async {
    await tester.pumpWidget(const SlidesApp());
    expect(find.byType(FluvieSlides), findsOneWidget);
    // The composition resolves post-frame, then the scene plays.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('fluvie slides'), findsOneWidget);
    expect(find.text('a Video, presented live'), findsOneWidget);
  });
}
