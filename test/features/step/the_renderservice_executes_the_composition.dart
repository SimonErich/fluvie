import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

Future<void> theRenderserviceExecutesTheComposition(WidgetTester tester) async {
  final compositionFinder = find.byType(VideoComposition);
  expect(compositionFinder, findsOneWidget);

  final element = tester.element(compositionFinder);
  final service = RenderService();
  
  // This should not throw
  final config = service.createConfigFromContext(element);
  
  expect(config.timeline.fps, 30);
  expect(config.timeline.durationInFrames, 90);
}
