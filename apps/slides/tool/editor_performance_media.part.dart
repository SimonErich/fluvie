part of 'editor_performance.dart';

Future<void> _measureDecodeTiers(WidgetTester tester, Map<String, Object?> results) async {
  final tiers = <String, Object?>{};
  await tester.runAsync(() async {
    const source = MediaSource.file(_source);
    for (final edge in [3840, 1920, 960]) {
      final scope = resolverScope(null, clipDecodeMaxEdge: edge, streamClipFrames: false);
      try {
        await scope.resolver.preResolveAll([source]);
        final metadata = await scope.resolver.probeClip(source);
        expect(metadata.width, 3840);
        expect(metadata.height, 2160);
        expect(metadata.fps, 24);
        expect(metadata.frameCount, 144);
        final timings = <double>[];
        for (final frame in [0, 24, 48, 72, 96, 120, 143]) {
          final clock = Stopwatch()..start();
          await scope.resolver.preResolveClip(source, [frame]);
          clock.stop();
          timings.add(clock.elapsedMicroseconds / 1000);
        }
        final image = scope.resolver.decodedClipFrame(source, 143);
        tiers['$edge'] = {
          ..._summary(timings),
          'decodedWidth': image.width,
          'decodedHeight': image.height,
          'rgbaBytesPerFrame': image.width * image.height * 4,
          'processRssBytes': ProcessInfo.currentRss,
        };
      } finally {
        await scope.dispose();
      }
    }
  });
  results['sourceFrameDecodeByTier'] = tiers;
}

Future<void> _measurePreview(
  WidgetTester tester,
  EditorDocument document,
  Map<String, Object?> results,
) async {
  final host = GlobalKey<DocumentPreviewHostState>();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: DocumentPreviewHost(key: host, document: document),
      ),
    ),
  );
  final clock = Stopwatch()..start();
  Object? error;
  var done = false;
  final pending = host.currentState!
      .render(0)
      .then(
        (image) {
          image.dispose();
          done = true;
        },
        onError: (Object caught) {
          error = caught;
          done = true;
        },
      );
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (!done && DateTime.now().isBefore(deadline)) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
  }
  expect(done, isTrue, reason: 'Preview generation exceeded 90 seconds');
  await pending;
  clock.stop();
  expect(error, isNull);
  expect(done, isTrue);
  results['settledPreviewGenerationMs'] = clock.elapsedMicroseconds / 1000;
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}
