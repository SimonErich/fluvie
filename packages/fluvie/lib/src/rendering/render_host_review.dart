part of 'render_host.dart';

Future<Map<String, Object?>> _captureReview({
  required RenderHostContext host,
  required _MountedHostComposition mounted,
  FutureOr<Video> Function()? videoFactory,
}) async {
  final request = host.invocation;
  final session = mounted.session;
  final width = mounted.width;
  final height = mounted.height;
  final total = request.frameCount ?? session.prepared.totalFrames;
  if (total < 1 || total > session.prepared.totalFrames) {
    throw ArgumentError('Review frame count must fit the authored composition.');
  }
  var selected =
      (request.reviewFrames.isEmpty
            ? <int>{
                0,
                total ~/ 2,
                total - 1,
                ...host.video.sceneStartFrames.where((frame) => frame < total),
              }.toList()
            : request.reviewFrames.toSet().toList())
        ..sort();
  if (request.reviewFrames.isEmpty && selected.length > 24) {
    selected = [
      for (var index = 0; index < 24; index++)
        selected[(index * (selected.length - 1) / 23).round()],
    ];
  }
  if (selected.length > 24 || selected.any((frame) => frame < 0 || frame >= total)) {
    throw ArgumentError('Review accepts up to 24 sample indexes within 0..${total - 1}.');
  }
  final output = Directory(
    request.reviewOutputDir?.isNotEmpty ?? false ? request.reviewOutputDir! : request.outputDir,
  );
  final samples = <Map<String, Object?>>[];
  final hashes = <int, String>{};
  final textFindings = <Map<String, Object?>>[];
  final fonts = await host.runAsync(() async {
    final manifest = jsonDecode(await host.assets.loadString('FontManifest.json')) as List;
    return <String>{
      fluvieDefaultFontFamily,
      for (final entry in manifest.cast<Map<String, Object?>>()) entry['family']! as String,
    };
  });

  await host.runAsync(() async {
    await output.create(recursive: true);
    return null;
  });
  for (final frame in selected) {
    final pixels = await mounted.frameAt(frame);
    textFindings.addAll(
      inspectRenderedText(
        boundaryKey: mounted.boundary,
        frame: frame,
        fps: session.fps,
        totalFrames: total,
        bundledFonts: fonts ?? const {},
      ),
    );
    final hash = sha256.convert(pixels.rgba).toString();
    hashes[frame] = hash;
    final path = '${output.absolute.path}/frame_$frame.png';
    await host.runAsync(() async {
      await _writeReviewPng(pixels, File(path));
      return null;
    });
    samples.add({
      'frame': frame,
      'timeSeconds': frame / session.fps,
      'filePath': path,
      'sha256': hash,
      'hashKind': 'rgba',
      'width': width,
      'height': height,
    });
  }
  final mismatches = <Map<String, Object?>>[];
  if (request.reviewDeterminism) {
    for (final frame in selected.reversed) {
      final pixels = await mounted.frameAt(frame);
      final actual = sha256.convert(pixels.rgba).toString();
      if (actual != hashes[frame]) {
        mismatches.add({
          'code': 'seek_order_changes_pixels',
          'check': 'seek_order',
          'frame': frame,
          'expected': hashes[frame],
          'actual': actual,
          'remedy':
              'Derive painted state from the authored frame. Avoid accumulating state across builds or seeks.',
        });
      }
    }
  }
  final seekMismatches = mismatches.length;
  if (request.reviewDeterminism) {
    try {
      mismatches.addAll(
        await _reviewFreshMount(
          host: host,
          original: mounted,
          frames: selected,
          hashes: hashes,
          videoFactory: videoFactory,
        ),
      );
    } on RenderCancelledException {
      rethrow;
    } on Object catch (error) {
      mismatches.add({
        'code': 'fresh_mount_failed',
        'check': 'fresh_mount',
        'message': '$error',
        'remedy':
            'Make the entry factory and widget preparation reusable. Check inputs and resource lifetimes across mounts.',
      });
    }
  }

  return {
    'samples': samples,
    'quality': {
      'findings': textFindings,
      'scope':
          'Laid-out Flutter paragraphs at selected frames. Reading time uses the declared timing window. '
          'Custom painters, rasterized text and actual glyph font substitution are not inspected.',
      'checks': ['paragraph_bounds', 'declared_reading_window', 'bundled_font_families'],
    },
    'determinism': {
      'checked': request.reviewDeterminism,
      'ok': request.reviewDeterminism ? mismatches.isEmpty : null,
      'method': 'reverse_seek_and_fresh_mount',
      'checks': [
        {
          'method': 'same_session_reverse_seek',
          'checked': request.reviewDeterminism,
          'ok': request.reviewDeterminism ? seekMismatches == 0 : null,
        },
        {
          'method': 'fresh_mount',
          'checked': request.reviewDeterminism,
          'ok': request.reviewDeterminism ? mismatches.length == seekMismatches : null,
          'factoryEvaluated': request.reviewDeterminism && videoFactory != null,
        },
      ],
      'mismatches': mismatches,
      'scope':
          'Selected frames and fresh widget state in this host; the entry is re-evaluated only when a factory is provided. Global state, every frame and cross-platform identity are outside this check.',
    },
  };
}

Future<void> _writeReviewPng(RawFrame frame, File file) async {
  final ready = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    frame.rgba,
    frame.width,
    frame.height,
    ui.PixelFormat.rgba8888,
    ready.complete,
  );
  final image = await ready.future;
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) throw StateError('The engine could not encode a review sample.');
    await file.writeAsBytes(
      png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
      flush: true,
    );
  } finally {
    image.dispose();
  }
}
