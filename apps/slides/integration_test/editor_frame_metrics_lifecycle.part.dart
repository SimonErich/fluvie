part of 'editor_e2e_test.dart';

void _registerMetricsLifecycle() {
  testWidgets('finishing a real frame measurement survives test cleanup', (tester) async {
    final metrics = await EditorFrameMetrics.start(tester);
    await tester.pumpWidget(const ColoredBox(color: Color(0xFF123456)));
    final report = await metrics.finish(tester);
    expect(report['count'], greaterThan(0));
  });
}
