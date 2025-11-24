import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

Future<void> theFinalVideoFileDurationIsExactly30Seconds(
    WidgetTester tester) async {
  final compositionFinder = find.byType(VideoComposition);
  final composition = tester.widget<VideoComposition>(compositionFinder);
  
  final durationSeconds = composition.durationInFrames / composition.fps;
  expect(durationSeconds, 3.0);
}
