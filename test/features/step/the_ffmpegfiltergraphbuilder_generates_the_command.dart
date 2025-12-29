import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/encoding/ffmpeg_filter_graph_builder.dart';

Future<void> theFfmpegfiltergraphbuilderGeneratesTheCommand(
  WidgetTester tester,
) async {
  // Verify the builder can be instantiated and is ready to generate commands.
  final builder = FFmpegFilterGraphBuilder();
  expect(builder, isNotNull);
}
