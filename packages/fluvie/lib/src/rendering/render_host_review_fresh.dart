part of 'render_host.dart';

Future<List<Map<String, Object?>>> _reviewFreshMount({
  required RenderHostContext host,
  required _MountedHostComposition original,
  required List<int> frames,
  required Map<int, String> hashes,
  FutureOr<Video> Function()? videoFactory,
}) async {
  await original.close();
  host.cancellation.throwIfCancelled();
  final video = videoFactory == null
      ? original.video
      : await _reviewVideoFactory(host, videoFactory);
  host.cancellation.throwIfCancelled();
  final scope = resolverScope(
    null,
    assetBundle: host.assets,
    whenCancelled: host.cancellation.whenCancelled,
  );
  final fresh = _MountedHostComposition(host, video, scope.resolver);
  final mismatches = <Map<String, Object?>>[];
  try {
    Map<String, Object> description(_MountedHostComposition mount) => {
      'width': mount.width,
      'height': mount.height,
      'fps': mount.video.fps,
      'frameCount': mount.video.totalFrames,
    };
    final expected = description(original);
    final actual = description(fresh);
    if (expected.entries.any((entry) => actual[entry.key] != entry.value)) {
      return [
        {
          'code': 'fresh_mount_changes_composition',
          'check': 'fresh_mount',
          'expected': expected,
          'actual': actual,
          'remedy':
              'Keep canvas, fps and duration stable. Use explicit inputs and seeded choices in the entry factory.',
        },
      ];
    }
    await fresh.prepare();
    for (final frame in frames) {
      final pixels = await fresh.frameAt(frame);
      final actual = sha256.convert(pixels.rgba).toString();
      if (actual != hashes[frame]) {
        mismatches.add({
          'code': 'fresh_mount_changes_pixels',
          'check': 'fresh_mount',
          'frame': frame,
          'expected': hashes[frame],
          'actual': actual,
          'remedy':
              'Use explicit seeds and authored frame time. Avoid random or wall-clock choices in the entry factory and initState.',
        });
      }
    }
    return mismatches;
  } finally {
    try {
      await fresh.close();
    } finally {
      await host.runAsync(() async {
        await scope.dispose();
        return null;
      });
    }
  }
}

Future<Video> _reviewVideoFactory(
  RenderHostContext host,
  FutureOr<Video> Function() factory,
) async {
  final video = await _runHostAsync(host, () => host.cancellation.run(() async => await factory()));
  host.cancellation.throwIfCancelled();
  if (video == null) throw StateError('The video factory returned no Video.');
  return video;
}
