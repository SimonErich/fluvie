import 'package:flutter_test/flutter_test.dart';
import 'utilities_context.dart';

/// Usage: I generate 5 keyframes
Future<void> iGenerate5Keyframes(WidgetTester tester) async {
  final range = getCurrentRange();
  final keyframes = range.keyframes(5);
  setKeyframes(keyframes);
}
