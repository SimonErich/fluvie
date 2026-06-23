/// The widget test `fluvie init` writes to `test/`, so a scaffolded project is
/// testable from the first run.
library;

/// The source of a widget test that builds the composition and pumps a frame,
/// asserting it mounts without error.
///
/// [importLine] imports the composition; [functionName] is the builder.
String widgetTestSource({required String importLine, required String functionName}) => _test
    .replaceFirst('{{IMPORT}}', importLine)
    .replaceFirst('{{FUNCTION}}', functionName)
    .replaceAll('{{FUNCTION_REF}}', functionName);

const String _test = '''
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
{{IMPORT}}

void main() {
  testWidgets('{{FUNCTION_REF}} builds and pumps a frame without error', (tester) async {
    final video = {{FUNCTION}}();
    expect(video.totalFrames, greaterThan(0));

    await tester.pumpWidget(
      RenderModeContext(
        mode: RenderMode.preview,
        child: RenderControllerScope(
          controller: RenderController(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: video.width.toDouble(),
              height: video.height.toDouble(),
              child: video,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
''';
