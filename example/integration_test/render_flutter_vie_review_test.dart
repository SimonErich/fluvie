// Integration test to render the FlutterVienna 2025 Review video
// Run with: flutter test integration_test/render_flutter_vie_review_test.dart -d linux
// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart';

import 'package:fluvie_example/gallery/examples/example_flutter_vie_review.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Render FlutterVienna 2025 Review video', (WidgetTester tester) async {
    final example = ExampleFlutterVieReview();
    final boundaryKey = GlobalKey();
    final compositionKey = GlobalKey();
    int currentFrame = 0;
    String? outputPath;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: SizedBox(
                  width: 1920,
                  height: 1080,
                  child: FrameProvider(
                    key: compositionKey,
                    frame: currentFrame,
                    child: example.buildComposition(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Find the VideoComposition context
    BuildContext? compositionContext;
    final element = compositionKey.currentContext as Element?;
    if (element != null) {
      void visit(Element e) {
        if (e.widget is VideoComposition) {
          compositionContext = e;
          return;
        }
        e.visitChildren(visit);
      }
      element.visitChildren(visit);
    }

    expect(compositionContext, isNotNull, reason: 'VideoComposition not found');

    // Create render service and config
    final renderService = RenderService();
    final config = renderService.createConfigFromContext(compositionContext!);

    debugPrint('Starting render: ${config.timeline.durationInFrames} frames');
    debugPrint('Resolution: ${config.timeline.width}x${config.timeline.height}');

    // Render the video
    outputPath = await renderService.execute(
      config: config,
      repaintBoundaryKey: boundaryKey,
      onFrameUpdate: (frame) {
        currentFrame = frame;
        if (frame % 30 == 0) {
          debugPrint('Rendering frame $frame / ${config.timeline.durationInFrames}');
        }
      },
    );

    debugPrint('Render complete: $outputPath');

    // Copy to target directory
    const targetDir = '/home/simonerich/DEL/flutterreview';
    final targetPath = '$targetDir/flutter_vienna_2025_review.mp4';

    final sourceFile = File(outputPath);
    expect(await sourceFile.exists(), isTrue, reason: 'Output file not created');

    await Directory(targetDir).create(recursive: true);
    await sourceFile.copy(targetPath);

    debugPrint('Video saved to: $targetPath');
    expect(await File(targetPath).exists(), isTrue);
  });
}
